import SwiftUI
import SwiftData

struct SearchBooksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var localBooks: [Book]
    private let provider: any BookMetadataProvider
    @State private var query = ""
    @State private var results: [BookSearchResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    init(provider: any BookMetadataProvider = OpenLibraryMetadataProvider()) {
        self.provider = provider
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Searching books…")
            } else if let errorMessage, results.isEmpty {
                ContentUnavailableView("Search Unavailable", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
            } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView("Find a Book", systemImage: "magnifyingglass", description: Text("Search by title, author, series, or ISBN."))
            } else if results.isEmpty {
                ContentUnavailableView("No Books Found", systemImage: "books.vertical", description: Text("Try a different title, author, series, or ISBN."))
            } else {
                List(results) { result in
                    NavigationLink {
                        SearchResultDetailView(result: result, provider: provider)
                    } label: {
                        SearchResultRow(result: result)
                    }
                }
            }
        }
        .navigationTitle("Search Books")
        .searchable(text: $query, prompt: "Title, author, series, or ISBN")
        .onChange(of: query) { _, newValue in scheduleSearch(for: newValue) }
        .onDisappear { searchTask?.cancel() }
    }

    private func scheduleSearch(for query: String) {
        searchTask?.cancel()
        let localResults = matchingLocalBooks(for: query)
        results = localResults
        errorMessage = nil
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isLoading = false
            return
        }
        isLoading = true
        searchTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(400))
                try Task.checkCancellation()
                let searchResults = try await provider.search(query: query)
                try Task.checkCancellation()
                results = BookSearchRanking.ordered(merge(local: localResults, remote: searchResults), for: query)
                isLoading = false
            } catch is CancellationError {
                // A newer query superseded this search.
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func matchingLocalBooks(for query: String) -> [BookSearchResult] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return [] }
        return localBooks.filter { book in
            book.title.lowercased().contains(needle)
                || book.author?.name.lowercased().contains(needle) == true
                || book.isbn?.contains(needle) == true
                || book.seriesMemberships.contains { $0.series?.name.lowercased().contains(needle) == true }
        }.map { book in
            BookSearchResult(
                id: "local-\(book.id.uuidString)",
                title: book.title,
                subtitle: book.subtitle,
                authorName: book.author?.name,
                isbn: book.isbn,
                seriesName: book.seriesMemberships.first?.series?.name,
                firstPublishedYear: nil,
                coverID: nil
            )
        }
    }

    private func merge(local: [BookSearchResult], remote: [BookSearchResult]) -> [BookSearchResult] {
        local + remote.filter { candidate in
            !local.contains {
                ($0.isbn != nil && $0.isbn == candidate.isbn)
                    || ($0.title.caseInsensitiveCompare(candidate.title) == .orderedSame
                        && $0.authorName?.caseInsensitiveCompare(candidate.authorName ?? "") == .orderedSame)
            }
        }
    }
}

private struct SearchResultRow: View {
    let result: BookSearchResult

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let coverID = result.coverID {
                AsyncImage(url: URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-S.jpg")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                }
                .frame(width: 42, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title).font(.headline)
                Text(result.authorName ?? "Unknown Author").foregroundStyle(.secondary)
                if let seriesName = result.seriesName {
                    Text(seriesName).font(.caption).foregroundStyle(.secondary)
                }
                if let year = result.firstPublishedYear {
                    Text("First published \(String(year))").font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 3)
    }
}

private struct SearchResultDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let result: BookSearchResult
    let provider: any BookMetadataProvider
    @State private var message: String?
    @State private var isImportingSeries = false
    @State private var isChoosingFollowScope = false
    @State private var addedUserBook: UserBook?

    var body: some View {
        List {
            Section {
                Text(result.title).font(.title2.weight(.semibold))
                Text(result.authorName ?? "Unknown Author").foregroundStyle(.secondary)
                if let subtitle = result.subtitle { Text(subtitle).foregroundStyle(.secondary) }
            }
            Section("Details") {
                if let seriesName = result.seriesName { LabeledContent("Series", value: seriesName) }
                if let isbn = result.isbn { LabeledContent("ISBN", value: isbn) }
                if let year = result.firstPublishedYear { LabeledContent("First published", value: String(year)) }
            }
            Section {
                Button("Add to Library") {
                    Task {
                        addedUserBook = await addSelectedBookAndSeries()
                    }
                }
                Button("Follow Book") {
                    if result.seriesName == nil {
                        followOnlyThisBook()
                    } else {
                        isChoosingFollowScope = true
                    }
                }
            }
            .disabled(isImportingSeries)
            if isImportingSeries {
                Section { HStack { ProgressView(); Text("Finding books in this series…") } }
            }
        }
        .navigationTitle("Book")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Book Buddy", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("Done") { dismiss() }
        } message: {
            Text(message ?? "")
        }
        .confirmationDialog("Follow \(result.title)", isPresented: $isChoosingFollowScope, titleVisibility: .visible) {
            Button("This Book") { followOnlyThisBook() }
            if let seriesName = result.seriesName {
                Button("Entire Series: \(seriesName)") { followEntireSeries() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This book belongs to a series. Choose whether Book Buddy should track this book or the whole series.")
        }
        .sheet(item: $addedUserBook) { userBook in
            EditReadingView(userBook: userBook)
        }
    }

    @MainActor
    private func addSelectedBookAndSeries() async -> UserBook? {
        let book = await cacheSelectedBookAndSeries(addToLibrary: true)
        let userBook = SeriesLibraryService.addToLibrary(book, context: modelContext)
        do {
            try modelContext.save()
            return userBook
        } catch {
            message = "Book Buddy couldn't save this book. Please try again."
            return nil
        }
    }

    @MainActor
    private func cacheSelectedBookAndSeries(addToLibrary: Bool = false) async -> Book {
        isImportingSeries = true
        defer { isImportingSeries = false }

        let selectedBook = addToLibrary
            ? SearchLibraryService.add(result, context: modelContext)
            : SearchLibraryService.cache(result, context: modelContext)
        if let seriesName = result.seriesName,
           let selectedSeries = selectedBook.seriesMemberships.first(where: {
               $0.series?.name.caseInsensitiveCompare(seriesName) == .orderedSame
           })?.series {
            do {
                let candidates = try await provider.search(query: seriesName)
                let normalizedSeriesName = normalized(seriesName)
                let seriesCandidates = candidates
                    .filter { $0.seriesName.map(normalized) == normalizedSeriesName }
                seriesCandidates.forEach { _ = SearchLibraryService.cache($0, context: modelContext) }

                // Some provider records omit a series tag on later works. When
                // the direct series search is sparse, look up title + author and
                // accept only same-author related results into this known series.
                if seriesCandidates.count < 2, let authorName = result.authorName, !authorName.isEmpty {
                    let relatedCandidates = try await provider.search(query: "\(result.title) \(authorName)")
                    relatedCandidates
                        .filter {
                            $0.id != result.id
                                && $0.authorName?.caseInsensitiveCompare(authorName) == .orderedSame
                        }
                        .forEach { _ = SearchLibraryService.cache($0, in: selectedSeries, context: modelContext) }
                }
            } catch {
                // The selected book can still be saved when companion discovery is unavailable.
            }
        }
        return selectedBook
    }

    private func followOnlyThisBook() {
        Task {
            let book = await cacheSelectedBookAndSeries()
            FollowingService.followBook(book, context: modelContext)
            message = "Following this book."
        }
    }

    private func followEntireSeries() {
        Task {
            let book = await cacheSelectedBookAndSeries()
            if let series = book.seriesMemberships.first?.series {
                FollowingService.followSeries(series, context: modelContext)
                message = "Following \(series.name)."
            } else {
                FollowingService.followBook(book, context: modelContext)
                message = "Following this book."
            }
        }
    }

    private func normalized(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
