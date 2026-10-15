import Foundation
import SwiftData
import CoreLocation

struct EventDiscoveryQuery: Sendable {
    let authorNames: [String]
    let seriesNames: [String]
    let upcomingBookTitles: [String]
    let locations: [EventSearchLocation]
}

struct EventSearchLocation: Sendable {
    let name: String
    let latitude: Double
    let longitude: Double
    let radiusMiles: Double
}

struct DiscoveredLiteraryEvent: Sendable {
    let title: String
    let details: String?
    let startsAt: Date
    let endsAt: Date?
    let venueName: String?
    let address: String?
    let city: String?
    let latitude: Double?
    let longitude: Double?
    let type: LiteraryEventType
    let source: String
    let sourceURL: String?
    let externalID: String?
    let authorName: String?
    let bookTitle: String?
    let seriesName: String?
}

protocol LiteraryEventProvider: Sendable {
    func discoverEvents(matching query: EventDiscoveryQuery) async throws -> [DiscoveredLiteraryEvent]
}

/// Reads a public iCalendar feed. iCalendar is widely used by libraries,
/// bookstores, festivals, and author sites, and requires no user credential.
struct ICalendarEventProvider: LiteraryEventProvider {
    let feedURL: URL
    let sourceName: String
    private let session: URLSession

    init(feedURL: URL, sourceName: String, session: URLSession = .shared) {
        self.feedURL = feedURL; self.sourceName = sourceName; self.session = session
    }

    func discoverEvents(matching query: EventDiscoveryQuery) async throws -> [DiscoveredLiteraryEvent] {
        let (data, response) = try await session.data(from: feedURL)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw EventDiscoveryError.invalidResponse }
        return ICalendarParser.events(from: data, source: sourceName, sourceURL: feedURL.absoluteString)
            .filter { $0.startsAt >= Calendar.current.startOfDay(for: .now) }
            .filter { event in EventDiscoveryService.matches(event: event, query: query) }
            .filter { event in EventDiscoveryService.isWithinConfiguredLocations(event: event, locations: query.locations) }
    }
}

enum EventDiscoveryError: LocalizedError {
    case invalidResponse
    var errorDescription: String? { "Event information returned an unexpected response." }
}

struct EventRefreshResult { var discovered = 0; var created = 0; var updated = 0 }

enum EventDiscoveryService {
    @MainActor static func refreshConfiguredSources(context: ModelContext) async throws -> EventRefreshResult {
        let sources = ((try? context.fetch(FetchDescriptor<EventSourcePreference>())) ?? []).filter(\.isEnabled)
        var total = EventRefreshResult()
        for source in sources {
            guard let url = URL(string: source.feedURL), url.scheme?.hasPrefix("http") == true else { continue }
            let result = try await refresh(provider: ICalendarEventProvider(feedURL: url, sourceName: source.name), context: context)
            total.discovered += result.discovered; total.created += result.created; total.updated += result.updated
        }
        return total
    }
    @MainActor static func refresh(provider: any LiteraryEventProvider, context: ModelContext) async throws -> EventRefreshResult {
        let query = discoveryQuery(context: context)
        let discovered = try await provider.discoverEvents(matching: query)
        var result = EventRefreshResult(discovered: discovered.count)
        let existing = (try? context.fetch(FetchDescriptor<LiteraryEvent>())) ?? []
        for event in discovered {
            if let stored = existing.first(where: { isDuplicate($0, event) }) {
                update(stored, from: event); result.updated += 1
            } else {
                context.insert(makeEvent(from: event, context: context)); result.created += 1
            }
        }
        try context.save()
        return result
    }

    @MainActor static func discoveryQuery(context: ModelContext) -> EventDiscoveryQuery {
        let authors = ((try? context.fetch(FetchDescriptor<FollowedAuthor>())) ?? []).compactMap { $0.author?.name }
        let series = ((try? context.fetch(FetchDescriptor<FollowedSeries>())) ?? []).compactMap { $0.series?.name }
        let releasedBooks = ((try? context.fetch(FetchDescriptor<Release>())) ?? []).compactMap { release -> String? in
            guard let date = release.releaseDate, date >= .now else { return nil }; return release.book?.title
        }
        let followedBooks = ((try? context.fetch(FetchDescriptor<FollowedBook>())) ?? []).compactMap { $0.book?.title }
        let locations = ((try? context.fetch(FetchDescriptor<EventLocationPreference>())) ?? []).filter(\.isEnabled).map {
            EventSearchLocation(name: $0.name, latitude: $0.latitude, longitude: $0.longitude, radiusMiles: $0.radiusMiles)
        }
        return EventDiscoveryQuery(authorNames: authors, seriesNames: series, upcomingBookTitles: Array(Set(releasedBooks + followedBooks)), locations: locations)
    }

    static func matches(event: DiscoveredLiteraryEvent, query: EventDiscoveryQuery) -> Bool {
        let text = [event.title, event.details, event.authorName, event.bookTitle, event.seriesName].compactMap { $0 }.joined(separator: " ").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let terms = query.authorNames + query.seriesNames + query.upcomingBookTitles
        return terms.contains { text.contains($0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)) }
    }

    static func isWithinConfiguredLocations(event: DiscoveredLiteraryEvent, locations: [EventSearchLocation]) -> Bool {
        guard !locations.isEmpty else { return true }
        guard let latitude = event.latitude, let longitude = event.longitude else { return true }
        let eventLocation = CLLocation(latitude: latitude, longitude: longitude)
        return locations.contains { eventLocation.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude)) <= $0.radiusMiles * 1_609.344 }
    }

    @MainActor private static func makeEvent(from event: DiscoveredLiteraryEvent, context: ModelContext) -> LiteraryEvent {
        let text = [event.title, event.details, event.authorName, event.bookTitle, event.seriesName].compactMap { $0 }.joined(separator: " ")
        return LiteraryEvent(title: event.title, details: event.details, startsAt: event.startsAt, endsAt: event.endsAt, venueName: event.venueName, address: event.address, city: event.city, latitude: event.latitude, longitude: event.longitude, type: event.type, source: event.source, sourceURL: event.sourceURL, externalID: event.externalID, author: author(named: event.authorName, orMentionedIn: text, context: context), book: book(titled: event.bookTitle, orMentionedIn: text, context: context), series: series(named: event.seriesName, orMentionedIn: text, context: context))
    }
    private static func update(_ stored: LiteraryEvent, from event: DiscoveredLiteraryEvent) { stored.title = event.title; stored.details = event.details; stored.startsAt = event.startsAt; stored.endsAt = event.endsAt; stored.venueName = event.venueName; stored.address = event.address; stored.city = event.city; stored.latitude = event.latitude; stored.longitude = event.longitude; stored.typeRawValue = event.type.rawValue; stored.sourceURL = event.sourceURL; stored.lastChecked = .now }
    private static func isDuplicate(_ stored: LiteraryEvent, _ event: DiscoveredLiteraryEvent) -> Bool { if let externalID = event.externalID, stored.externalID == externalID, stored.source == event.source { return true }; return stored.title.caseInsensitiveCompare(event.title) == .orderedSame && abs(stored.startsAt.timeIntervalSince(event.startsAt)) < 60 && stored.venueName == event.venueName }
    @MainActor private static func author(named name: String?, orMentionedIn text: String, context: ModelContext) -> Author? { let authors = ((try? context.fetch(FetchDescriptor<Author>())) ?? []); if let name, let author = authors.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) { return author }; return authors.first { mentions($0.name, in: text) } }
    @MainActor private static func book(titled title: String?, orMentionedIn text: String, context: ModelContext) -> Book? { let books = ((try? context.fetch(FetchDescriptor<Book>())) ?? []); if let title, let book = books.first(where: { $0.title.caseInsensitiveCompare(title) == .orderedSame }) { return book }; return books.first { mentions($0.title, in: text) } }
    @MainActor private static func series(named name: String?, orMentionedIn text: String, context: ModelContext) -> Series? { let series = ((try? context.fetch(FetchDescriptor<Series>())) ?? []); if let name, let item = series.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) { return item }; return series.first { mentions($0.name, in: text) } }
    private static func mentions(_ candidate: String, in text: String) -> Bool { candidate.count > 2 && text.range(of: candidate, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
}

private enum ICalendarParser {
    static func events(from data: Data, source: String, sourceURL: String) -> [DiscoveredLiteraryEvent] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        let rawLines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var lines: [String] = []
        for line in rawLines {
            if (line.hasPrefix(" ") || line.hasPrefix("\t")), !lines.isEmpty {
                lines[lines.count - 1] += line.trimmingCharacters(in: .whitespaces)
            } else { lines.append(line) }
        }
        var blocks: [[String]] = []; var current: [String] = []; var inEvent = false
        for line in lines {
            if line == "BEGIN:VEVENT" { inEvent = true; current = [] }
            else if line == "END:VEVENT", inEvent { blocks.append(current); inEvent = false }
            else if inEvent { current.append(line) }
        }
        return blocks.compactMap { block in
            var values: [String: String] = [:]
            for line in block {
                guard let separator = line.firstIndex(of: ":") else { continue }
                let key = String(line[..<separator]).components(separatedBy: ";")[0]
                if values[key] == nil { values[key] = String(line[line.index(after: separator)...]) }
            }
            guard let title = values["SUMMARY"], let startsAt = date(values["DTSTART"]) else { return nil }
            let location = values["LOCATION"]
            return DiscoveredLiteraryEvent(title: title, details: values["DESCRIPTION"], startsAt: startsAt, endsAt: date(values["DTEND"]), venueName: location, address: location, city: nil, latitude: nil, longitude: nil, type: type(for: title), source: source, sourceURL: values["URL"] ?? sourceURL, externalID: values["UID"], authorName: nil, bookTitle: nil, seriesName: nil)
        }
    }
    private static func date(_ value: String?) -> Date? { guard let value else { return nil }; let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .current; f.dateFormat = value.contains("T") ? "yyyyMMdd'T'HHmmss" : "yyyyMMdd"; return f.date(from: value.replacingOccurrences(of: "Z", with: "")) }
    private static func type(for title: String) -> LiteraryEventType { let text = title.lowercased(); if text.contains("sign") { return .signing }; if text.contains("launch") { return .launchParty }; if text.contains("festival") { return .festival }; if text.contains("library") { return .library }; if text.contains("talk") || text.contains("conversation") { return .authorTalk }; return .literary }
}
