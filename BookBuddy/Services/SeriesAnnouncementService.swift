import Foundation
import SwiftData

/// A confirmed upcoming entry in a series. The source is retained on the
/// resulting Release so a reader can verify dates themselves.
struct SeriesAnnouncement: Sendable, Equatable {
    let seriesName: String
    let title: String
    let authorName: String
    let position: Double
    let releaseDate: Date
    let source: String
    let sourceURL: String
    let confidence: ReleaseConfidence
}

protocol SeriesAnnouncementProvider: Sendable {
    func announcements() async throws -> [SeriesAnnouncement]
}

/// Curated announcements bridge the period between a publisher's public
/// announcement and catalog metadata becoming available from book providers.
/// Keep this list small and sourced; it is never inferred from reader data.
struct CuratedSeriesAnnouncementProvider: SeriesAnnouncementProvider {
    func announcements() async throws -> [SeriesAnnouncement] {
        [
            SeriesAnnouncement(
                seriesName: "A Court of Thorns and Roses",
                title: "A Court of Splintered Harmony",
                authorName: "Sarah J. Maas",
                position: 6,
                releaseDate: date("2026-10-27"),
                source: "Bloomsbury",
                sourceURL: "https://www.bloomsbury.com/us/discover/sarah-j-maas/a-court-of-thorns-and-roses/",
                confidence: .confirmed
            ),
            SeriesAnnouncement(
                seriesName: "A Court of Thorns and Roses",
                title: "A Court of Forgotten Melody",
                authorName: "Sarah J. Maas",
                position: 7,
                releaseDate: date("2027-01-12"),
                source: "Bloomsbury",
                sourceURL: "https://www.bloomsbury.com/us/discover/sarah-j-maas/a-court-of-thorns-and-roses/",
                confidence: .confirmed
            ),
            SeriesAnnouncement(
                seriesName: "Fae & Alchemy",
                title: "Fae & Alchemy Book 3",
                authorName: "Callie Hart",
                position: 3,
                releaseDate: date("2027-09-07"),
                source: "Hachette Book Group",
                sourceURL: "https://www.hachettebookgroup.com/titles/callie-hart/fae-alchemy-book-3/9781538774274/",
                confidence: .confirmed
            )
        ]
    }

    private func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: "\(value)T00:00:00Z")!
    }
}

enum SeriesAnnouncementService {
    @MainActor
    static func refresh(
        provider: any SeriesAnnouncementProvider = CuratedSeriesAnnouncementProvider(),
        context: ModelContext
    ) async throws -> Int {
        let followedSeries = ((try? context.fetch(FetchDescriptor<FollowedSeries>())) ?? []).compactMap(\.series)
        let announcements = try await provider.announcements()
        var added = 0

        for announcement in announcements {
            guard let series = followedSeries.first(where: {
                $0.name.caseInsensitiveCompare(announcement.seriesName) == .orderedSame
            }) else { continue }

            let result = BookSearchResult(
                id: "announcement-\(normalized(announcement.seriesName))-\(Int(announcement.position))",
                title: announcement.title,
                subtitle: nil,
                authorName: announcement.authorName,
                isbn: nil,
                seriesName: announcement.seriesName,
                firstPublishedYear: Calendar.current.component(.year, from: announcement.releaseDate),
                coverID: nil
            )
            let book = SearchLibraryService.cache(result, in: series, context: context)
            if let membership = book.seriesMemberships.first(where: { $0.series?.id == series.id }) {
                membership.position = announcement.position
            }

            if let release = ReleaseTrackingService.release(for: book, context: context) {
                release.releaseDate = announcement.releaseDate
                release.statusRawValue = ReleaseStatus.upcoming.rawValue
                release.source = announcement.source
                release.sourceURL = announcement.sourceURL
                release.confidenceRawValue = announcement.confidence.rawValue
                release.lastChecked = .now
            } else {
                context.insert(Release(
                    book: book,
                    releaseDate: announcement.releaseDate,
                    status: .upcoming,
                    source: announcement.source,
                    sourceURL: announcement.sourceURL,
                    confidence: announcement.confidence
                ))
                added += 1
            }
        }
        try context.save()
        return added
    }

    private static func normalized(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
