import SwiftUI
import SwiftData
@preconcurrency import CoreLocation
import MapKit

struct CalendarView: View {
    private enum DisplayMode: String, CaseIterable, Identifiable {
        case month = "Month"
        case agenda = "Agenda"
        var id: String { rawValue }
    }

    @Query private var releases: [Release]
    @Query private var events: [LiteraryEvent]
    @State private var displayMode: DisplayMode = .month
    @State private var displayedMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now

    private var datedReleases: [Release] {
        releases.filter { $0.releaseDate != nil }.sorted { ($0.releaseDate ?? .distantFuture) < ($1.releaseDate ?? .distantFuture) }
    }
    private var upcomingEvents: [LiteraryEvent] { events.filter { $0.startsAt >= Calendar.current.startOfDay(for: .now) }.sorted { $0.startsAt < $1.startsAt } }

    var body: some View {
        NavigationStack {
            Group {
                if datedReleases.isEmpty && upcomingEvents.isEmpty {
                    ContentUnavailableView("Nothing on Your Calendar", systemImage: "calendar", description: Text("Known releases and literary events will appear here."))
                } else if displayMode == .month {
                    MonthReleaseCalendar(month: $displayedMonth, releases: datedReleases, events: upcomingEvents)
                } else {
                    ReleaseAgenda(releases: datedReleases, events: upcomingEvents)
                }
            }
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Calendar display", selection: $displayMode) {
                        ForEach(DisplayMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                }
            }
        }
    }
}

private struct MonthReleaseCalendar: View {
    @Binding var month: Date
    let releases: [Release]
    let events: [LiteraryEvent]
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Button { moveMonth(by: -1) } label: { Image(systemName: "chevron.left") }
                    Spacer()
                    Text(month, format: .dateTime.month(.wide).year())
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Button { moveMonth(by: 1) } label: { Image(systemName: "chevron.right") }
                }
                .padding(.horizontal)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in
                        Text(weekday.prefix(1)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                        if let date {
                            MonthDayCell(date: date, releases: releasesForDay(date), events: eventsForDay(date))
                        } else {
                            Color.clear.frame(height: 52)
                        }
                    }
                }
                .padding(.horizontal)

                let monthReleases = releases.filter { release in
                    guard let date = release.releaseDate else { return false }
                    return calendar.isDate(date, equalTo: month, toGranularity: .month)
                }
                if !monthReleases.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This Month").font(.headline)
                        ForEach(monthReleases) { release in ReleaseCalendarLink(release: release) }
                    }
                    .padding()
                }
                let monthEvents = events.filter { calendar.isDate($0.startsAt, equalTo: month, toGranularity: .month) }
                if !monthEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Events This Month").font(.headline)
                        ForEach(monthEvents) { event in EventCalendarLink(event: event) }
                    }.padding()
                }
            }
            .padding(.top)
        }
    }

    private var days: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }
        let leadingDays = (calendar.component(.weekday, from: firstDay) - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leadingDays) + range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: firstDay) }
    }

    private func releasesForDay(_ date: Date) -> [Release] {
        releases.filter { release in
            guard let releaseDate = release.releaseDate else { return false }
            return calendar.isDate(releaseDate, inSameDayAs: date)
        }
    }
    private func eventsForDay(_ date: Date) -> [LiteraryEvent] { events.filter { calendar.isDate($0.startsAt, inSameDayAs: date) } }

    private func moveMonth(by value: Int) {
        month = calendar.date(byAdding: .month, value: value, to: month) ?? month
    }
}

private struct MonthDayCell: View {
    let date: Date
    let releases: [Release]
    let events: [LiteraryEvent]

    var body: some View {
        VStack(spacing: 3) {
            Text(date, format: .dateTime.day())
                .font(.subheadline)
            if !releases.isEmpty || !events.isEmpty {
                Circle().fill(.tint).frame(width: 6, height: 6)
                Text("\(releases.count + events.count)").font(.caption2).foregroundStyle(.secondary)
            } else {
                Color.clear.frame(height: 17)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52)
    }
}

private struct ReleaseAgenda: View {
    let releases: [Release]
    let events: [LiteraryEvent]

    var body: some View {
        List {
            ForEach(groupedReleases, id: \.key) { section in
                Section {
                    ForEach(section.value) { release in ReleaseCalendarLink(release: release) }
                } header: {
                    Text(section.key, format: .dateTime.month(.wide).year())
                }
            }
            ForEach(groupedEvents, id: \.key) { section in
                Section("Events · \(section.key.formatted(.dateTime.month(.wide).year()))") {
                    ForEach(section.value) { event in EventCalendarLink(event: event) }
                }
            }
        }
    }

    private var groupedReleases: [(key: Date, value: [Release])] {
        Dictionary(grouping: releases) { release in
            Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: release.releaseDate ?? .now)) ?? .now
        }
        .sorted { $0.key < $1.key }
    }
    private var groupedEvents: [(key: Date, value: [LiteraryEvent])] {
        Dictionary(grouping: events) { Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: $0.startsAt)) ?? .now }.sorted { $0.key < $1.key }
    }
}

private struct ReleaseCalendarLink: View {
    let release: Release

    var body: some View {
        NavigationLink {
            ReleaseDetailView(release: release)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(release.book?.title ?? "Unknown Book")
                    Text(release.book?.author?.name ?? "Unknown Author").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let date = release.releaseDate { Text(date, format: .dateTime.month().day()).foregroundStyle(.secondary) }
            }
        }
    }
}

private struct EventCalendarLink: View {
    let event: LiteraryEvent
    var body: some View {
        NavigationLink { EventDetailView(event: event) } label: {
            HStack {
                Image(systemName: event.type.symbolName).foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text(event.title)
                    if let venue = event.venueName { Text(venue).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer(); Text(event.startsAt, format: .dateTime.month().day()).foregroundStyle(.secondary)
            }
        }
    }
}

private struct EventDetailView: View {
    let event: LiteraryEvent
    var body: some View {
        List {
            Section("Event") {
                Text(event.title).font(.title3.weight(.semibold))
                LabeledContent("When") { Text(event.startsAt.formatted(date: .complete, time: .shortened)) }
                if let venue = event.venueName { LabeledContent("Where", value: venue) }
                if let address = event.address, address != event.venueName { LabeledContent("Address", value: address) }
                LabeledContent("Source", value: event.source)
                if let sourceURL = event.sourceURL, let url = URL(string: sourceURL) {
                    Link("Open Original Source", destination: url)
                }
                if let details = event.details { Text(details) }
            }
            if let author = event.author { Section("Author") { NavigationLink(author.name) { AuthorDetailView(author: author) } } }
            if let series = event.series { Section("Series") { NavigationLink(series.name) { SeriesDetailView(series: series) } } }
            if let userBook = event.book?.userBooks.first { Section("Book") { NavigationLink("Open Book Details") { BookDetailView(userBook: userBook) } } }
        }.navigationTitle("Event").navigationBarTitleDisplayMode(.inline)
    }
}

struct ReleaseDetailView: View {
    let release: Release

    var body: some View {
        List {
            Section("Release") {
                Text(release.book?.title ?? "Unknown Book").font(.title3.weight(.semibold))
                if let date = release.releaseDate { LabeledContent("Release Date") { Text(date, format: .dateTime.month().day().year()) } }
                LabeledContent("Status", value: release.status.title)
                LabeledContent("Source", value: release.source)
            }
            if let userBook = release.book?.userBooks.first {
                Section("Book") {
                    NavigationLink("Open Book Details") { BookDetailView(userBook: userBook) }
                }
            }
            if let book = release.book {
                Section("Find It Locally") {
                    NavigationLink("Search Nearby Bookstores") {
                        LocalBookstoreFinderView(book: book)
                    }
                    NavigationLink("Search for Preorders") {
                        LocalBookstoreFinderView(book: book, initialPurpose: .preorder)
                    }
                }
            }
            let series = release.book?.seriesMemberships.compactMap(\.series) ?? []
            if !series.isEmpty {
                Section("Series") {
                    ForEach(series) { series in
                        NavigationLink(series.name) { SeriesDetailView(series: series) }
                    }
                }
            }
        }
        .navigationTitle("Release")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LocalBookstoreFinderView: View {
    let book: Book
    @State private var purpose: LocalBookstoreSearchPurpose
    @State private var location = ""
    @State private var isLocating = false
    @State private var isSearching = false
    @State private var results: [LocalBookstoreSearchResult] = []
    @State private var candidates: [LocalBookstoreCandidate] = []
    @State private var currentLocationArea: LocalBookstoreSearchArea?
    @State private var errorMessage: String?
    @State private var errorTitle = "Couldn’t Search Local Bookstores"
    @State private var didSearch = false

    init(book: Book, initialPurpose: LocalBookstoreSearchPurpose = .availableNow) {
        self.book = book
        _purpose = State(initialValue: initialPurpose)
    }

    var body: some View {
        List {
            Section {
                Text(book.title).font(.title3.weight(.semibold))
                if let author = book.author?.name { Text(author).foregroundStyle(.secondary) }
                if let isbn = book.isbn, !isbn.isEmpty { Text("ISBN \(isbn)").font(.caption).foregroundStyle(.secondary) }
            }

            Section("Search Area") {
                Picker("Looking for", selection: $purpose) {
                    ForEach(LocalBookstoreSearchPurpose.allCases) { purpose in
                        Text(purpose.title).tag(purpose)
                    }
                }
                .pickerStyle(.segmented)
                TextField("City or area", text: $location)
                    .textInputAutocapitalization(.words)
                Button {
                    useCurrentLocation()
                } label: {
                    if isLocating { Label("Finding Your City…", systemImage: "location") }
                    else { Label("Use Current Location", systemImage: "location") }
                }
                .disabled(isLocating || isSearching)
                Text("Only your city or area—not your precise location—is sent to the search service.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    search()
                } label: {
                    if isSearching { Label("Checking Bookstore Sites…", systemImage: "magnifyingglass") }
                    else if purpose == .preorder { Label("Search for Preorders", systemImage: "cart") }
                    else { Label("Find It Locally", systemImage: "books.vertical") }
                }
                .disabled(location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching || isLocating)
            }

            if !results.isEmpty {
                Section("Nearby Bookstores") {
                    ForEach(sortedResults) { result in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(result.name).font(.headline)
                                Spacer()
                                Text(result.availability.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(result.availability == .checkWithStore ? .orange : .green)
                            }
                            Text(result.detail).font(.subheadline).foregroundStyle(.secondary)
                            if let distance = distance(for: result) {
                                Text("\(distance.formatted(.number.precision(.fractionLength(1)))) mi away")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Link("Open Store Listing", destination: result.sourceURL)
                        }
                        .padding(.vertical, 3)
                    }
                }
            } else if didSearch, !isSearching {
                ContentUnavailableView("No Online Listings Found", systemImage: "book.closed", description: Text("Try another nearby city, or call a favorite local bookstore—they may have stock that is not listed online."))
            }
        }
        .navigationTitle("Find It Locally")
        .navigationBarTitleDisplayMode(.inline)
        .alert(errorTitle, isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func useCurrentLocation() {
        isLocating = true
        Task {
            defer { isLocating = false }
            do {
                let localityService = CurrentLocalityService()
                let area = try await localityService.searchArea()
                location = area.name
                currentLocationArea = area
            } catch {
                errorTitle = "Couldn’t Use Current Location"
                errorMessage = error.localizedDescription
            }
        }
    }

    private func search() {
        isSearching = true
        errorTitle = "Couldn’t Search Local Bookstores"
        errorMessage = nil
        didSearch = false
        results = []
        candidates = []
        Task {
            defer { isSearching = false }
            do {
                guard let configuration = try RecapGatewayCredentialsStore.shared.configuration() else {
                    throw LocalBookstoreSearchError.notConfigured
                }
                let area = try await resolvedSearchArea()
                let localCandidates = try await LocalBookstoreMapService.nearbyBookstores(around: area.location)
                guard !localCandidates.isEmpty else { throw LocalBookstoreSearchError.noNearbyBookstores }
                candidates = localCandidates
                results = try await LocalBookstoreGatewayProvider(configuration: configuration).search(for: book, near: area.name, candidates: localCandidates, purpose: purpose)
                didSearch = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var sortedResults: [LocalBookstoreSearchResult] {
        results.sorted { (distance(for: $0) ?? .greatestFiniteMagnitude) < (distance(for: $1) ?? .greatestFiniteMagnitude) }
    }

    private func distance(for result: LocalBookstoreSearchResult) -> Double? {
        guard let candidateID = result.candidateID else { return nil }
        return candidates.first(where: { $0.id == candidateID })?.distanceMiles
    }

    private func resolvedSearchArea() async throws -> LocalBookstoreSearchArea {
        if let currentLocationArea, currentLocationArea.name == location { return currentLocationArea }
        return try await LocalBookstoreMapService.searchArea(named: location)
    }
}

private final class CurrentLocalityService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Void, Error>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
    }

    func searchArea() async throws -> LocalBookstoreSearchArea {
        if manager.authorizationStatus == .notDetermined {
            try await requestAuthorization()
        }
        guard manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways else {
            throw CurrentLocalityError.permissionDenied
        }
        let location = try await requestLocation()
        let placemark = try await CLGeocoder().reverseGeocodeLocation(location).first
        let parts = [placemark?.locality, placemark?.administrativeArea, placemark?.country]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { throw CurrentLocalityError.unavailable }
        return LocalBookstoreSearchArea(name: parts.joined(separator: ", "), location: location)
    }

    private func requestAuthorization() async throws {
        try await withCheckedThrowingContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    private func requestLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation = authorizationContinuation, manager.authorizationStatus != .notDetermined else { return }
        authorizationContinuation = nil
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            continuation.resume()
        } else {
            continuation.resume(throwing: CurrentLocalityError.permissionDenied)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        if let location = locations.last { continuation.resume(returning: location) }
        else { continuation.resume(throwing: CurrentLocalityError.unavailable) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // The Simulator commonly reports kCLErrorDomain error 0 when it has no
        // simulated location. The raw platform error is not useful to readers.
        locationContinuation?.resume(throwing: CurrentLocalityError.unavailable)
        locationContinuation = nil
    }
}

private struct LocalBookstoreSearchArea {
    let name: String
    let location: CLLocation
}

private enum LocalBookstoreMapService {
    static func searchArea(named name: String) async throws -> LocalBookstoreSearchArea {
        guard let placemark = try await CLGeocoder().geocodeAddressString(name).first,
              let location = placemark.location
        else { throw CurrentLocalityError.unavailable }
        return LocalBookstoreSearchArea(name: name, location: location)
    }

    static func nearbyBookstores(around origin: CLLocation) async throws -> [LocalBookstoreCandidate] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "bookstore"
        request.region = MKCoordinateRegion(
            center: origin.coordinate,
            latitudinalMeters: 80_000,
            longitudinalMeters: 80_000
        )
        let response = try await MKLocalSearch(request: request).start()
        let sorted = response.mapItems.compactMap { item -> (name: String, address: String, distance: Double)? in
            guard let name = item.name,
                  let location = item.placemark.location,
                  !isExcludedStore(name)
            else { return nil }
            let address = item.placemark.title ?? name
            return (name, address, origin.distance(from: location) / 1_609.344)
        }
        .sorted { $0.distance < $1.distance }

        var seen = Set<String>()
        return sorted.compactMap { store in
            let key = store.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard seen.insert(key).inserted else { return nil }
            return LocalBookstoreCandidate(
                id: "store-\(seen.count)",
                name: store.name,
                address: store.address,
                distanceMiles: (store.distance * 10).rounded() / 10
            )
        }
        .prefix(12)
        .map { $0 }
    }

    private static func isExcludedStore(_ name: String) -> Bool {
        let normalized = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return ["church", "religious", "catholic", "christian"].contains { normalized.contains($0) }
    }
}

enum CurrentLocalityError: LocalizedError {
    case permissionDenied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Allow location access to use your current city, or enter a city manually."
        case .unavailable:
            #if targetEnvironment(simulator)
            "The Simulator does not have a location. Enter a city manually, or set one in Xcode’s Debug > Location menu."
            #else
            "Book Buddy could not determine your city. Enter one manually instead."
            #endif
        }
    }
}
