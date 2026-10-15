import Foundation
import SwiftData

enum LiteraryEventType: String, CaseIterable, Sendable {
    case authorTalk = "Author talk"
    case signing = "Signing"
    case launchParty = "Launch party"
    case bookstore = "Bookstore event"
    case library = "Library event"
    case festival = "Festival"
    case literary = "Literary event"

    var symbolName: String {
        switch self {
        case .authorTalk: "person.2"
        case .signing: "pencil.and.scribble"
        case .launchParty: "sparkles"
        case .bookstore: "books.vertical"
        case .library: "building.columns"
        case .festival: "tent"
        case .literary: "book"
        }
    }
}

/// Locally cached information about a literary event discovered from a public
/// source. An event may relate to a followed author, series, or upcoming book.
@Model final class LiteraryEvent {
    @Attribute(.unique) var id: UUID
    var title: String
    var details: String?
    var startsAt: Date
    var endsAt: Date?
    var venueName: String?
    var address: String?
    var city: String?
    var latitude: Double?
    var longitude: Double?
    var typeRawValue: String
    var source: String
    var sourceURL: String?
    var externalID: String?
    var lastChecked: Date
    var radarDismissedAt: Date?
    var author: Author?
    var book: Book?
    var series: Series?

    init(
        id: UUID = UUID(), title: String, details: String? = nil, startsAt: Date,
        endsAt: Date? = nil, venueName: String? = nil, address: String? = nil,
        city: String? = nil, latitude: Double? = nil, longitude: Double? = nil,
        type: LiteraryEventType = .literary, source: String, sourceURL: String? = nil,
        externalID: String? = nil, lastChecked: Date = .now, radarDismissedAt: Date? = nil,
        author: Author? = nil, book: Book? = nil, series: Series? = nil
    ) {
        self.id = id; self.title = title; self.details = details; self.startsAt = startsAt
        self.endsAt = endsAt; self.venueName = venueName; self.address = address; self.city = city
        self.latitude = latitude; self.longitude = longitude; self.typeRawValue = type.rawValue
        self.source = source; self.sourceURL = sourceURL; self.externalID = externalID
        self.lastChecked = lastChecked; self.radarDismissedAt = radarDismissedAt
        self.author = author; self.book = book; self.series = series
    }

    var type: LiteraryEventType { LiteraryEventType(rawValue: typeRawValue) ?? .literary }
}

@Model final class EventLocationPreference {
    @Attribute(.unique) var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var radiusMiles: Double
    var isEnabled: Bool

    init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double, radiusMiles: Double = 25, isEnabled: Bool = true) {
        self.id = id; self.name = name; self.latitude = latitude; self.longitude = longitude
        self.radiusMiles = radiusMiles; self.isEnabled = isEnabled
    }
}

@Model final class EventSourcePreference {
    @Attribute(.unique) var id: UUID
    var name: String
    var feedURL: String
    var isEnabled: Bool
    /// Existing sources are reader-added by default; a future bundled catalog can
    /// mark its vetted sources as `bookBuddy` without changing discovery logic.
    var kindRawValue: String = EventSourceKind.readerAdded.rawValue

    init(id: UUID = UUID(), name: String, feedURL: String, isEnabled: Bool = true, kind: EventSourceKind = .readerAdded) {
        self.id = id; self.name = name; self.feedURL = feedURL; self.isEnabled = isEnabled; self.kindRawValue = kind.rawValue
    }

    var kind: EventSourceKind { EventSourceKind(rawValue: kindRawValue) ?? .readerAdded }
}

enum EventSourceKind: String {
    case bookBuddy
    case readerAdded

    var label: String {
        switch self {
        case .bookBuddy: "Book Buddy source"
        case .readerAdded: "Your added source"
        }
    }
}
