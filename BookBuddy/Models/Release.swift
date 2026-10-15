import Foundation
import SwiftData

enum ReleaseStatus: String, CaseIterable {
    case announced
    case upcoming
    case released
    case unknown

    var title: String { rawValue.capitalized }
}

enum ReleaseConfidence: String, CaseIterable {
    case confirmed
    case likely
    case unknown

    var title: String { rawValue.capitalized }
}

/// Cached release metadata for a canonical book. It is shared by every local
/// following relationship that makes the book relevant to the reader.
@Model final class Release {
    @Attribute(.unique) var id: UUID
    var releaseDate: Date?
    var statusRawValue: String
    var source: String
    var sourceURL: String?
    var confidenceRawValue: String
    var lastChecked: Date
    var previousReleaseDate: Date?
    var radarDismissedAt: Date?
    var book: Book?

    init(
        id: UUID = UUID(),
        book: Book? = nil,
        releaseDate: Date? = nil,
        status: ReleaseStatus = .unknown,
        source: String,
        sourceURL: String? = nil,
        confidence: ReleaseConfidence = .unknown,
        lastChecked: Date = .now,
        previousReleaseDate: Date? = nil,
        radarDismissedAt: Date? = nil
    ) {
        self.id = id
        self.book = book
        self.releaseDate = releaseDate
        self.statusRawValue = status.rawValue
        self.source = source
        self.sourceURL = sourceURL
        self.confidenceRawValue = confidence.rawValue
        self.lastChecked = lastChecked
        self.previousReleaseDate = previousReleaseDate
        self.radarDismissedAt = radarDismissedAt
    }

    var status: ReleaseStatus { ReleaseStatus(rawValue: statusRawValue) ?? .unknown }
    var confidence: ReleaseConfidence { ReleaseConfidence(rawValue: confidenceRawValue) ?? .unknown }
}
