import SwiftUI
import SwiftData

struct SeriesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Series.name) private var series: [Series]
    @State private var isPresentingAddSeries = false

    var body: some View {
        Group {
            if series.isEmpty {
                ContentUnavailableView("No Series Yet", systemImage: "square.stack.3d.up", description: Text("Add a series when you add a book, or create one here."))
            } else {
                List(series) { series in
                    NavigationLink {
                        SeriesDetailView(series: series)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(series.name).font(.headline)
                            Text("\(series.books.count) book\(series.books.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Series")
        .toolbar {
            Button("Add Series", systemImage: "plus") { isPresentingAddSeries = true }
        }
        .sheet(isPresented: $isPresentingAddSeries) {
            AddSeriesView()
        }
    }
}

private struct AddSeriesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form { TextField("Series name", text: $name) }
                .navigationTitle("Add Series")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            modelContext.insert(Series(name: name.trimmingCharacters(in: .whitespacesAndNewlines)))
                            dismiss()
                        }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
    }
}

struct SeriesDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userBooks: [UserBook]
    let series: Series
    @State private var isPresentingAddBook = false
    @State private var isPresentingOrderEditor = false
    @State private var isGeneratingRecap = false
    @State private var isRecapExpanded = true
    @State private var recapError: String?
    @State private var isFindingBooks = false
    @State private var discoveryMessage: String?

    private var orderedBooks: [SeriesBook] {
        SeriesReadingOrder.sorted(series.books)
    }

    private var progress: (read: Int, total: Int) {
        let books = orderedBooks.compactMap(\.book)
        return (books.filter { book in userBooks.contains { $0.book?.id == book.id && $0.readingStatus == .read } }.count, books.count)
    }

    private var booksNotInLibrary: [Book] {
        orderedBooks.compactMap(\.book).filter { book in
            !userBooks.contains { $0.book?.id == book.id }
        }
    }

    var body: some View {
        List {
            Section {
                Text(series.name).font(.title2.weight(.semibold))
                if progress.total > 0 {
                    ProgressView(value: Double(progress.read), total: Double(progress.total))
                    Text("\(progress.read) of \(progress.total) books read")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Following") {
                Button {
                    FollowingService.toggleSeries(series, context: modelContext)
                } label: {
                    Label(FollowingService.followedSeries(for: series, context: modelContext) == nil ? "Follow Series" : "Unfollow Series", systemImage: "bookmark")
                }
            }

            Section("What You Need to Remember") {
                if let recap = RecapGenerationService.cachedRecap(for: series, context: modelContext) {
                    Button {
                        withAnimation { isRecapExpanded.toggle() }
                    } label: {
                        Label(isRecapExpanded ? "Hide Recap" : "Show Recap", systemImage: isRecapExpanded ? "chevron.up" : "chevron.down")
                    }
                    if isRecapExpanded {
                        Text(.init(recap.content))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Generated \(recap.generatedAt, format: .dateTime.month().day().year())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Generate a recap from the books you have marked Read. Unread books are never included.")
                        .foregroundStyle(.secondary)
                }
                Button {
                    generateRecap()
                } label: {
                    if isGeneratingRecap { Label("Generating…", systemImage: "sparkles") }
                    else if RecapGenerationService.cachedRecap(for: series, context: modelContext) != nil {
                        Label("Regenerate Recap", systemImage: "sparkles")
                    } else {
                        Label("Generate Recap", systemImage: "sparkles")
                    }
                }
                .disabled(isGeneratingRecap)
            }

            if !booksNotInLibrary.isEmpty {
                Section("Library") {
                    Button("Add \(booksNotInLibrary.count) Book\(booksNotInLibrary.count == 1 ? "" : "s") to Library") {
                        _ = SeriesLibraryService.addAllToLibrary(booksNotInLibrary, context: modelContext)
                    }
                }
            }

            Section("Reading Order") {
                ForEach(orderedBooks) { membership in
                    if let book = membership.book {
                        let userBook = userBooks.first { $0.book?.id == book.id }
                        NavigationLink {
                            if let userBook {
                                BookDetailView(userBook: userBook)
                            } else {
                                DiscoveredBookDetailView(book: book)
                            }
                        } label: {
                            SeriesBookRow(membership: membership, userBook: userBook)
                        }
                    } else {
                        SeriesBookRow(membership: membership, userBook: nil)
                    }
                }
                .onDelete(perform: removeMemberships)
            }
        }
        .navigationTitle("Series")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Add Book", systemImage: "plus") { isPresentingAddBook = true }
            Button("Find Series Books", systemImage: "arrow.clockwise") { findSeriesBooks() }
                .disabled(isFindingBooks || orderedBooks.isEmpty)
            Button("Edit Reading Order", systemImage: "arrow.up.arrow.down") { isPresentingOrderEditor = true }
        }
        .sheet(isPresented: $isPresentingAddBook) {
            AddBookToSeriesView(series: series)
        }
        .sheet(isPresented: $isPresentingOrderEditor) {
            EditSeriesOrderView(series: series)
        }
        .alert("Couldn’t Generate Recap", isPresented: Binding(get: { recapError != nil }, set: { if !$0 { recapError = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(recapError ?? "")
        }
        .alert("Series Books", isPresented: Binding(get: { discoveryMessage != nil }, set: { if !$0 { discoveryMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(discoveryMessage ?? "")
        }
    }

    private func removeMemberships(at offsets: IndexSet) {
        offsets.map { orderedBooks[$0] }.forEach(modelContext.delete)
    }

    private func generateRecap() {
        isGeneratingRecap = true
        Task {
            defer { isGeneratingRecap = false }
            do {
                // Give SwiftUI a chance to render the in-progress state before
                // starting the network request.
                await Task.yield()
                guard let configuration = try RecapGatewayCredentialsStore.shared.configuration() else {
                    throw RecapGenerationError.providerNotConfigured
                }
                _ = try await RecapGenerationService.generate(
                    for: series,
                    provider: CloudflareRecapProvider(configuration: configuration),
                    context: modelContext,
                    forceRefresh: true
                )
            } catch {
                recapError = error.localizedDescription
            }
        }
    }

    private func findSeriesBooks() {
        guard let seed = orderedBooks.compactMap(\.book).first(where: {
            $0.author?.name.isEmpty == false
        }), let authorName = seed.author?.name else { return }

        isFindingBooks = true
        Task {
            defer { isFindingBooks = false }
            do {
                let candidates = try await OpenLibraryMetadataProvider().search(query: "\(seed.title) \(authorName)")
                let knownBookIDs = Set(series.books.compactMap { $0.book?.openLibraryWorkID })
                let added = candidates.filter {
                    $0.id != seed.openLibraryWorkID
                        && $0.authorName?.caseInsensitiveCompare(authorName) == .orderedSame
                        && !knownBookIDs.contains($0.id)
                }
                added.forEach { _ = SearchLibraryService.cache($0, in: series, context: modelContext) }
                try modelContext.save()
                discoveryMessage = added.isEmpty
                    ? "No additional related books were found."
                    : "Added \(added.count) book\(added.count == 1 ? "" : "s") to \(series.name)."
            } catch {
                discoveryMessage = error.localizedDescription
            }
        }
    }
}

private struct EditSeriesOrderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let series: Series
    @State private var positions: [UUID: String] = [:]

    private var memberships: [SeriesBook] { SeriesReadingOrder.sorted(series.books) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(memberships) { membership in
                        HStack {
                            Text(membership.book?.title ?? "Unknown Book")
                            Spacer()
                            TextField("Number", text: positionBinding(for: membership))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                } footer: {
                    Text("Numbered books always appear first in reading order. Leave a number blank to use publication year as a fallback.")
                }
            }
            .navigationTitle("Reading Order")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard positions.isEmpty else { return }
                positions = Dictionary(uniqueKeysWithValues: memberships.map { ($0.id, $0.position.map { String($0) } ?? "") })
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        for membership in memberships {
                            membership.position = Double(positions[membership.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                        }
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }

    private func positionBinding(for membership: SeriesBook) -> Binding<String> {
        Binding(
            get: { positions[membership.id] ?? "" },
            set: { positions[membership.id] = $0 }
        )
    }
}

private struct DiscoveredBookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let book: Book
    @State private var isChoosingFollowScope = false
    @State private var addedUserBook: UserBook?

    var body: some View {
        List {
            Section {
                Text(book.title).font(.title2.weight(.semibold))
                Text(book.author?.name ?? "Unknown Author").foregroundStyle(.secondary)
            }
            if !book.seriesMemberships.isEmpty {
                Section("Series") {
                    ForEach(book.seriesMemberships) { membership in
                        if let series = membership.series {
                            LabeledContent(series.name, value: membership.position.map { "#\($0.formatted())" } ?? membership.type)
                        }
                    }
                }
            }
            Section {
                Button("Add to Library") {
                    addedUserBook = SeriesLibraryService.addToLibrary(book, context: modelContext)
                }
                Button(FollowingService.followedBook(for: book, context: modelContext) == nil ? "Follow Book" : "Unfollow Book") {
                    if FollowingService.followedBook(for: book, context: modelContext) != nil {
                        FollowingService.toggleBook(book, context: modelContext)
                    } else {
                        isChoosingFollowScope = true
                    }
                }
            }
        }
        .navigationTitle("Book")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Follow \(book.title)", isPresented: $isChoosingFollowScope, titleVisibility: .visible) {
            Button("This Book") { FollowingService.followBook(book, context: modelContext) }
            ForEach(book.seriesMemberships.compactMap(\.series)) { series in
                Button("Entire Series: \(series.name)") {
                    FollowingService.followSeries(series, context: modelContext)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This book belongs to a series. Choose whether Book Buddy should track this book or the whole series.")
        }
        .sheet(item: $addedUserBook) { userBook in
            EditReadingView(userBook: userBook)
        }
    }
}

private struct SeriesBookRow: View {
    let membership: SeriesBook
    let userBook: UserBook?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(membership.book?.title ?? "Unknown Book")
                Text([membership.position.map { "#\($0.formatted())" }, membership.type].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let userBook {
                    HStack(spacing: 4) {
                        Text(userBook.readingStatus.title)
                        if let rating = userBook.rating {
                            Text("· \(String(repeating: "★", count: Int(rating)))")
                        }
                        if let date = userBook.finishedReadingAt ?? userBook.startedReadingAt {
                            Text("· \(date.formatted(date: .abbreviated, time: .omitted))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.tint)
                } else {
                    Text("Not in Library")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if userBook?.readingStatus == .read { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
        }
    }
}

private struct AddBookToSeriesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.title) private var books: [Book]
    let series: Series
    @State private var selectedBookID: UUID?
    @State private var position = ""
    @State private var type = "Novel"

    private var availableBooks: [Book] { books.filter { book in !series.books.contains { $0.book?.id == book.id } } }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Book", selection: $selectedBookID) {
                    Text("Choose a book").tag(UUID?.none)
                    ForEach(availableBooks) { Text($0.title).tag(Optional($0.id)) }
                }
                TextField("Number", text: $position).keyboardType(.decimalPad)
                TextField("Type", text: $type)
            }
            .navigationTitle("Add to Series")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let selectedBookID, let book = books.first(where: { $0.id == selectedBookID }) else { return }
                        modelContext.insert(SeriesBook(series: series, book: book, position: Double(position), type: type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Novel" : type.trimmingCharacters(in: .whitespacesAndNewlines)))
                        dismiss()
                    }
                    .disabled(selectedBookID == nil)
                }
            }
        }
    }
}
