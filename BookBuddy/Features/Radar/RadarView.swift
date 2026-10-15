import SwiftUI
import SwiftData

struct RadarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var releases: [Release]
    @Query private var events: [LiteraryEvent]
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    private var radarReleases: [Release] {
        let recentlyReleased = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
        return releases.filter { release in
            guard release.radarDismissedAt == nil,
                  let date = release.releaseDate,
                  date >= recentlyReleased,
                  isRelevant(release),
                  !isRead(release.book)
            else { return false }
            return true
        }
        .sorted { ($0.releaseDate ?? .distantFuture) < ($1.releaseDate ?? .distantFuture) }
    }

    private var radarEvents: [LiteraryEvent] {
        events.filter { $0.radarDismissedAt == nil && $0.startsAt >= Calendar.current.startOfDay(for: .now) && isRelevant($0) }
            .sorted { $0.startsAt < $1.startsAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if radarReleases.isEmpty && radarEvents.isEmpty {
                    ContentUnavailableView("Nothing New Yet", systemImage: "dot.radiowaves.left.and.right", description: Text("Radar will show upcoming and newly released books from the authors, series, and books you follow."))
                } else {
                    List {
                        if !radarReleases.isEmpty {
                            Section("Releases") {
                                ForEach(radarReleases) { release in
                                    ReleaseRadarRow(release: release, reason: relevanceReason(for: release))
                                        .swipeActions { Button("Dismiss", systemImage: "eye.slash", role: .destructive) { release.radarDismissedAt = .now; try? modelContext.save() } }
                                }
                            }
                        }
                        if !radarEvents.isEmpty {
                            Section("Events") {
                                ForEach(radarEvents) { event in
                                    EventRadarRow(event: event, reason: relevanceReason(for: event))
                                        .swipeActions { Button("Dismiss", systemImage: "eye.slash", role: .destructive) { event.radarDismissedAt = .now; try? modelContext.save() } }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Radar")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { refresh() } label: {
                        if isRefreshing { ProgressView() } else { Label("Refresh Releases", systemImage: "arrow.clockwise") }
                    }
                    .disabled(isRefreshing)
                }
            }
            .alert("Couldn’t Refresh Releases", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) { } } message: { Text(errorMessage ?? "") }
        }
    }

    private func refresh() {
        isRefreshing = true
        Task {
            defer { isRefreshing = false }
            do {
                _ = try await SeriesAnnouncementService.refresh(context: modelContext)
                _ = try await ReleaseTrackingService.refresh(provider: OpenLibraryReleaseProvider(), context: modelContext)
                _ = try await EventDiscoveryService.refreshConfiguredSources(context: modelContext)
                await ReleaseNotificationService.rescheduleAll(context: modelContext)
            }
            catch { errorMessage = error.localizedDescription }
        }
    }

    private func isRead(_ book: Book?) -> Bool { book?.userBooks.contains { $0.readingStatus == .read } ?? false }

    private func isRelevant(_ release: Release) -> Bool {
        guard let book = release.book else { return false }
        if FollowingService.followedBook(for: book, context: modelContext) != nil { return true }
        if let author = book.author, FollowingService.followedAuthor(for: author, context: modelContext) != nil { return true }
        return book.seriesMemberships.contains { membership in
            guard let series = membership.series else { return false }
            return FollowingService.followedSeries(for: series, context: modelContext) != nil
        }
    }

    private func relevanceReason(for release: Release) -> String {
        guard let book = release.book else { return "Followed book" }
        if FollowingService.followedBook(for: book, context: modelContext) != nil { return "Followed book" }
        if let author = book.author, FollowingService.followedAuthor(for: author, context: modelContext) != nil { return "Followed author: \(author.name)" }
        if let series = book.seriesMemberships.compactMap(\.series).first(where: { FollowingService.followedSeries(for: $0, context: modelContext) != nil }) { return "Followed series: \(series.name)" }
        return "Followed book"
    }

    private func isRelevant(_ event: LiteraryEvent) -> Bool {
        if let author = event.author, FollowingService.followedAuthor(for: author, context: modelContext) != nil { return true }
        if let book = event.book, FollowingService.followedBook(for: book, context: modelContext) != nil { return true }
        if let series = event.series, FollowingService.followedSeries(for: series, context: modelContext) != nil { return true }
        return false
    }

    private func relevanceReason(for event: LiteraryEvent) -> String {
        if let author = event.author { return "Followed author: \(author.name)" }
        if let series = event.series { return "Followed series: \(series.name)" }
        return "Upcoming release"
    }
}

private struct ReleaseRadarRow: View {
    let release: Release
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(release.book?.title ?? "Unknown Book").font(.headline)
            Text(release.book?.author?.name ?? "Unknown Author").foregroundStyle(.secondary)
            if let releaseDate = release.releaseDate {
                Text(release.status == .released ? "Released \(releaseDate.formatted(date: .abbreviated, time: .omitted))" : "Releases \(releaseDate.formatted(date: .abbreviated, time: .omitted))").font(.subheadline.weight(.medium))
            }
            Text("\(reason) · \(release.confidence.title) confidence").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

private struct EventRadarRow: View {
    let event: LiteraryEvent
    let reason: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(event.title, systemImage: event.type.symbolName).font(.headline)
            if let venue = event.venueName, !venue.isEmpty { Text(venue).foregroundStyle(.secondary) }
            Text(event.startsAt.formatted(date: .abbreviated, time: .shortened)).font(.subheadline.weight(.medium))
            Text(reason).font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 3)
    }
}
