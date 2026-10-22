import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let userBook: UserBook
    @State private var isPresentingEditor = false
    @State private var isChoosingFollowScope = false
    @State private var isGeneratingSummary = false
    @State private var summaryError: String?
    @State private var isLoadingDescription = false

    var body: some View {
        List {
            Section {
                Text(userBook.book?.title ?? "Unknown Book")
                    .font(.title2.weight(.semibold))
                if let author = userBook.book?.author {
                    NavigationLink(author.name) {
                        AuthorDetailView(author: author)
                    }
                    .foregroundStyle(.secondary)
                } else {
                    Text("Unknown Author").foregroundStyle(.secondary)
                }
            }

            if let book = userBook.book {
                if let description = book.metadataDescription, !description.isEmpty {
                    Section("Description") {
                        Text(description)
                    }
                } else if isLoadingDescription {
                    Section("Description") {
                        HStack { ProgressView(); Text("Loading description…") }
                    }
                }

                if let release = ReleaseTrackingService.release(for: book, context: modelContext) {
                    Section("Release Information") {
                        if let date = release.releaseDate {
                            LabeledContent("Release Date") { Text(date, format: .dateTime.month().day().year()) }
                        }
                        LabeledContent("Status", value: release.status.title)
                        LabeledContent("Confidence", value: release.confidence.title)
                        LabeledContent("Source", value: release.source)
                        LabeledContent("Last Checked") { Text(release.lastChecked, format: .dateTime.month().day().year().hour().minute()) }
                        if let previousReleaseDate = release.previousReleaseDate {
                            LabeledContent("Previous Date") { Text(previousReleaseDate, format: .dateTime.month().day().year()) }
                        }
                        NavigationLink("Find It Locally") {
                            LocalBookstoreFinderView(book: book)
                        }
                    }
                }

                Section("Following") {
                    Button {
                        if FollowingService.followedBook(for: book, context: modelContext) != nil {
                            FollowingService.toggleBook(book, context: modelContext)
                        } else if book.seriesMemberships.isEmpty {
                            FollowingService.followBook(book, context: modelContext)
                        } else {
                            isChoosingFollowScope = true
                        }
                    } label: {
                        Label(FollowingService.followedBook(for: book, context: modelContext) == nil ? "Follow Book" : "Unfollow Book", systemImage: "bookmark")
                    }
                }

                Section("What You Need to Remember") {
                    if let summary = BookSummaryGenerationService.cachedSummary(for: book, context: modelContext) {
                        Text(summary.content)
                        Text("Generated \(summary.generatedAt, format: .dateTime.month().day().year())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if userBook.readingStatus == .read {
                        Text("Generate a spoiler-safe summary of this book after you have finished it.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Mark this book as Read before generating a summary.")
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        generateSummary()
                    } label: {
                        if isGeneratingSummary { Label("Generating…", systemImage: "sparkles") }
                        else { Label("Generate Book Summary", systemImage: "sparkles") }
                    }
                    .disabled(userBook.readingStatus != .read || isGeneratingSummary)
                }

                if !book.seriesMemberships.isEmpty {
                    Section("Series") {
                        ForEach(book.seriesMemberships) { membership in
                            if let series = membership.series {
                                NavigationLink {
                                    SeriesDetailView(series: series)
                                } label: {
                                    LabeledContent(series.name, value: seriesLabel(for: membership))
                                }
                            }
                        }
                    }
                }
            }

            Section("Reading") {
                LabeledContent("Status", value: userBook.readingStatus.title)

                if let rating = userBook.rating {
                    LabeledContent("Rating") {
                        Text(String(repeating: "★", count: Int(rating)))
                            .foregroundStyle(.yellow)
                    }
                }

                LabeledContent("Added") {
                    Text(userBook.addedAt, format: .dateTime.month().day().year())
                }

                if let startedReadingAt = userBook.startedReadingAt {
                    LabeledContent("Started") {
                        Text(startedReadingAt, format: .dateTime.month().day().year())
                    }
                }

                if let finishedReadingAt = userBook.finishedReadingAt {
                    LabeledContent("Finished") {
                        Text(finishedReadingAt, format: .dateTime.month().day().year())
                    }
                }
            }

            if let review = userBook.review, !review.isEmpty {
                Section("Your Review") {
                    Text(review)
                }
            }
        }
        .navigationTitle("Book Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    isPresentingEditor = true
                }
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            EditReadingView(userBook: userBook)
        }
        .task(id: userBook.book?.id) {
            await loadDescriptionIfNeeded()
        }
        .alert("Couldn’t Generate Summary", isPresented: Binding(get: { summaryError != nil }, set: { if !$0 { summaryError = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(summaryError ?? "")
        }
        .confirmationDialog("Follow \(userBook.book?.title ?? "this book")", isPresented: $isChoosingFollowScope, titleVisibility: .visible) {
            if let book = userBook.book {
                Button("This Book") {
                    FollowingService.followBook(book, context: modelContext)
                }
                ForEach(book.seriesMemberships.compactMap(\.series)) { series in
                    Button("Entire Series: \(series.name)") {
                        FollowingService.followSeries(series, context: modelContext)
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(followPrompt)
        }
    }

    private func seriesLabel(for membership: SeriesBook) -> String {
        let position = membership.position.map { "#\($0.formatted())" } ?? "Unnumbered"
        return "\(position) · \(membership.type)"
    }

    private var followPrompt: String {
        guard let book = userBook.book, !book.seriesMemberships.isEmpty else {
            return "Book Buddy will track release updates for this book."
        }
        return "This book belongs to a series. Choose whether Book Buddy should track this book or the whole series."
    }

    private func generateSummary() {
        isGeneratingSummary = true
        Task {
            defer { isGeneratingSummary = false }
            do {
                guard let configuration = try RecapGatewayCredentialsStore.shared.configuration() else {
                    throw RecapGenerationError.providerNotConfigured
                }
                _ = try await BookSummaryGenerationService.generate(
                    for: userBook,
                    provider: CloudflareRecapProvider(configuration: configuration),
                    context: modelContext
                )
            } catch {
                summaryError = error.localizedDescription
            }
        }
    }

    private func loadDescriptionIfNeeded() async {
        guard let book = userBook.book, let workID = book.openLibraryWorkID else { return }
        let provider = OpenLibraryMetadataProvider()
        if let existingDescription = book.metadataDescription,
           provider.isEnglishDescription(existingDescription) {
            return
        }
        isLoadingDescription = true
        defer { isLoadingDescription = false }
        do {
            book.metadataDescription = try await provider.description(forWorkID: workID)
            book.lastUpdated = .now
            try modelContext.save()
        } catch {
            // Descriptions are optional metadata. Keep the local book usable and retry on a later visit.
        }
    }
}
