import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserBook.addedAt, order: .reverse) private var books: [UserBook]
    @Query(sort: \Series.name) private var series: [Series]
    @Query(sort: \Author.name) private var authors: [Author]
    @Query private var followedBooks: [FollowedBook]
    @Query private var followedSeries: [FollowedSeries]
    @Query private var followedAuthors: [FollowedAuthor]
    @State private var isPresentingAddBook = false
    @AppStorage("library.section") private var selectedSectionRawValue = LibrarySection.books.rawValue
    @AppStorage("library.followedOnly") private var followedOnly = false
    @AppStorage("library.statusFilter") private var statusFilter = "all"
    @AppStorage("library.seriesFilter") private var seriesFilter = "all"
    @AppStorage("library.sortOrder") private var sortOrder = "recentlyAdded"

    private var displayedBooks: [UserBook] {
        books
            .filter { userBook in
                (statusFilter == "all" || userBook.readingStatus.rawValue == statusFilter)
                    && (seriesFilter == "all"
                        || (seriesFilter == "inSeries" && !(userBook.book?.seriesMemberships.isEmpty ?? true))
                        || (seriesFilter == "standalone" && (userBook.book?.seriesMemberships.isEmpty ?? true)))
                    && (!followedOnly || isFollowed(userBook.book))
            }
            .sorted(by: sort)
    }

    private var selectedSection: LibrarySection {
        LibrarySection(rawValue: selectedSectionRawValue) ?? .books
    }

    private var displayedSeries: [Series] {
        series.filter { !followedOnly || isFollowed($0) }
    }

    private var displayedAuthors: [Author] {
        authors.filter { !followedOnly || isFollowed($0) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Library section", selection: $selectedSectionRawValue) {
                    ForEach(LibrarySection.allCases) { section in
                        Text(section.title).tag(section.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])

                Toggle("Followed only", isOn: $followedOnly)
                    .font(.subheadline)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                libraryContent
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack {
                        NavigationLink {
                            SearchBooksView()
                        } label: {
                            Label("Search Books", systemImage: "magnifyingglass")
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Book", systemImage: "plus") {
                        isPresentingAddBook = true
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    if selectedSection == .books {
                        Menu {
                            Section("Reading Status") {
                                Picker("Reading Status", selection: $statusFilter) {
                                    Text("All statuses").tag("all")
                                    ForEach(ReadingStatus.allCases) { status in
                                        Text(status.title).tag(status.rawValue)
                                    }
                                }
                            }
                            Section("Series") {
                                Picker("Series", selection: $seriesFilter) {
                                    Text("All books").tag("all")
                                    Text("In a series").tag("inSeries")
                                    Text("Standalone").tag("standalone")
                                }
                            }
                            Section("Sort") {
                                Picker("Sort", selection: $sortOrder) {
                                    Text("Recently added").tag("recentlyAdded")
                                    Text("Started reading").tag("startedReading")
                                    Text("Finished reading").tag("finishedReading")
                                }
                            }
                        } label: {
                            Label("Filter and Sort", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddBook) {
                AddBookView()
            }
        }
    }

    @ViewBuilder
    private var libraryContent: some View {
        switch selectedSection {
        case .books:
            if books.isEmpty {
                ContentUnavailableView(
                    "Your Library Is Empty",
                    systemImage: "books.vertical",
                    description: Text("Add a book to begin building your reading history.")
                )
            } else {
                List {
                    if displayedBooks.isEmpty {
                        noMatches("books")
                        if hasBookFilters {
                            Button("Clear Book Filters") {
                                clearBookFilters()
                            }
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                        }
                    }
                    ForEach(displayedBooks) { userBook in
                        if let book = userBook.book {
                            NavigationLink {
                                BookDetailView(userBook: userBook)
                            } label: {
                                BookRow(userBook: userBook, book: book)
                            }
                        }
                    }
                    .onDelete(perform: deleteBooks)
                }
            }
        case .series:
            List {
                if displayedSeries.isEmpty {
                    noMatches("series")
                }
                ForEach(displayedSeries) { series in
                    NavigationLink {
                        SeriesDetailView(series: series)
                    } label: {
                        SeriesRow(series: series)
                    }
                }
            }
        case .authors:
            List {
                if displayedAuthors.isEmpty {
                    noMatches("authors")
                }
                ForEach(displayedAuthors) { author in
                    NavigationLink {
                        AuthorDetailView(author: author)
                    } label: {
                        AuthorRow(author: author)
                    }
                }
            }
        }
    }

    private func noMatches(_ itemName: String) -> some View {
        ContentUnavailableView(
            "No Matching \(itemName.capitalized)",
            systemImage: "line.3.horizontal.decrease.circle",
            description: Text(followedOnly ? "You are not following any \(itemName) yet." : "Try changing your Library filters.")
        )
        .listRowBackground(Color.clear)
    }

    private func isFollowed(_ book: Book?) -> Bool {
        followedBooks.contains { $0.book?.id == book?.id }
    }

    private func isFollowed(_ series: Series) -> Bool {
        followedSeries.contains { $0.series?.id == series.id }
    }

    private func isFollowed(_ author: Author) -> Bool {
        followedAuthors.contains { $0.author?.id == author.id }
    }

    private var hasBookFilters: Bool {
        followedOnly || statusFilter != "all" || seriesFilter != "all"
    }

    private func clearBookFilters() {
        followedOnly = false
        statusFilter = "all"
        seriesFilter = "all"
        sortOrder = "recentlyAdded"
    }

    private func deleteBooks(at offsets: IndexSet) {
        for index in offsets {
            guard let book = displayedBooks[safe: index] else { continue }
            modelContext.delete(book)
        }
    }

    private func sort(_ left: UserBook, _ right: UserBook) -> Bool {
        switch sortOrder {
        case "startedReading":
            return dateSort(left.startedReadingAt, right.startedReadingAt, tieBreaker: left.addedAt > right.addedAt)
        case "finishedReading":
            return dateSort(left.finishedReadingAt, right.finishedReadingAt, tieBreaker: left.addedAt > right.addedAt)
        default:
            return left.addedAt > right.addedAt
        }
    }

    private func dateSort(_ left: Date?, _ right: Date?, tieBreaker: Bool) -> Bool {
        switch (left, right) {
        case let (left?, right?) where left != right: return left > right
        case (.some, nil): return true
        case (nil, .some): return false
        default: return tieBreaker
        }
    }
}

private enum LibrarySection: String, CaseIterable, Identifiable {
    case books
    case series
    case authors

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

private struct BookRow: View {
    let userBook: UserBook
    let book: Book

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BookCoverThumbnail(coverID: book.coverID)
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                Text(book.author?.name ?? "Unknown Author")
                    .foregroundStyle(.secondary)
                Text(userBook.readingStatus.title)
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SeriesRow: View {
    let series: Series

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(series.name).font(.headline)
            Text("\(series.books.count) book\(series.books.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct AuthorRow: View {
    let author: Author

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(author.name).font(.headline)
            Text("\(author.books.count) book\(author.books.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct BookCoverThumbnail: View {
    let coverID: Int?

    var body: some View {
        Group {
            if let coverID, let url = URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-S.jpg") {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: 44, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.quaternary)
            Image(systemName: "book.closed.fill").foregroundStyle(.secondary)
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
