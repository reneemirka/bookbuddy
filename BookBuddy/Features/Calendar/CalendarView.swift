import SwiftUI
import SwiftData

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

private struct ReleaseDetailView: View {
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
