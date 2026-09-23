import SwiftUI

struct CalendarView: View {
    var body: some View {
        NavigationStack {
            PlaceholderContentView(
                title: "Calendar",
                message: "Upcoming releases, reminders, and author events will appear here."
            )
            .navigationTitle("Calendar")
        }
    }
}
