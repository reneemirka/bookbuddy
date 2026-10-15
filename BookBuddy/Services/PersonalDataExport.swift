import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct PersonalDataExport: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

enum PersonalDataExportService {
    @MainActor static func makeExport(context: ModelContext) throws -> PersonalDataExport {
        let userBooks = (try context.fetch(FetchDescriptor<UserBook>())).map { userBook in
            ExportedBook(title: userBook.book?.title ?? "Unknown Book", author: userBook.book?.author?.name, isbn: userBook.book?.isbn, status: userBook.readingStatus.rawValue, rating: userBook.rating, review: userBook.review, startedAt: userBook.startedReadingAt, finishedAt: userBook.finishedReadingAt)
        }
        let following = ExportedFollowing(
            books: (try context.fetch(FetchDescriptor<FollowedBook>())).compactMap { $0.book?.title },
            authors: (try context.fetch(FetchDescriptor<FollowedAuthor>())).compactMap { $0.author?.name },
            series: (try context.fetch(FetchDescriptor<FollowedSeries>())).compactMap { $0.series?.name }
        )
        let locations = try context.fetch(FetchDescriptor<EventLocationPreference>()).map { ExportedLocation(name: $0.name, latitude: $0.latitude, longitude: $0.longitude, radiusMiles: $0.radiusMiles, enabled: $0.isEnabled) }
        let snapshot = ExportSnapshot(exportedAt: .now, books: userBooks, following: following, eventLocations: locations)
        return PersonalDataExport(data: try JSONEncoder.pretty.encode(snapshot))
    }
}

private struct ExportSnapshot: Encodable { let exportedAt: Date; let books: [ExportedBook]; let following: ExportedFollowing; let eventLocations: [ExportedLocation] }
private struct ExportedBook: Encodable { let title: String; let author: String?; let isbn: String?; let status: String; let rating: Double?; let review: String?; let startedAt: Date?; let finishedAt: Date? }
private struct ExportedFollowing: Encodable { let books: [String]; let authors: [String]; let series: [String] }
private struct ExportedLocation: Encodable { let name: String; let latitude: Double; let longitude: Double; let radiusMiles: Double; let enabled: Bool }
private extension JSONEncoder { static var pretty: JSONEncoder { let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; return encoder } }
