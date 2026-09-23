import SwiftUI
import SwiftData

@main
struct BookBuddyApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [Author.self, Book.self, Series.self, SeriesBook.self, UserBook.self])
    }
}
