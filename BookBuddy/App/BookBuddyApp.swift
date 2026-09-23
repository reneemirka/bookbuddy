import SwiftUI
import SwiftData

@main
struct BookBuddyApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: Book.self)
    }
}
