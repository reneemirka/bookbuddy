import SwiftUI
import SwiftData
import UserNotifications
import UIKit
import AppIntents

final class BookBuddyAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        MonitoringSubscriptionService.saveDeviceToken(deviceToken)
        NotificationCenter.default.post(name: .monitoringDeviceTokenUpdated, object: nil)
    }
}

extension Notification.Name { static let monitoringDeviceTokenUpdated = Notification.Name("monitoringDeviceTokenUpdated") }

@main
struct BookBuddyApp: App {
    @UIApplicationDelegateAdaptor(BookBuddyAppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [
            Author.self, Book.self, Series.self, SeriesBook.self, UserBook.self,
            FollowedBook.self, FollowedAuthor.self, FollowedSeries.self, Release.self,
            SeriesRecap.self, BookSummary.self, LiteraryEvent.self,
            EventLocationPreference.self, EventSourcePreference.self
        ])
    }
}

/// Shared refresh work for both an ordinary app launch and the reader's
/// scheduled Shortcuts automation. Each operation is independent so a
/// temporary provider problem never prevents local reminders being refreshed.
@MainActor
enum BookBuddyRefreshService {
    static func refresh(context: ModelContext, includingWebDiscovery: Bool = false) async {
        _ = try? await SeriesAnnouncementService.refresh(context: context)
        _ = try? await ReleaseTrackingService.refresh(
            provider: OpenLibraryReleaseProvider(),
            context: context
        )
        _ = try? await EventDiscoveryService.refreshConfiguredSources(context: context)
        await ReleaseNotificationService.rescheduleAll(context: context)
        try? await MonitoringSubscriptionService.sync(context: context)
        if includingWebDiscovery {
            _ = try? await MonitoringSubscriptionService.refreshDiscoveries(context: context)
            await ReleaseNotificationService.rescheduleAll(context: context)
        }
    }

    static func refreshFromShortcut() async throws {
        let container = try ModelContainer(for:
            Author.self, Book.self, Series.self, SeriesBook.self, UserBook.self,
            FollowedBook.self, FollowedAuthor.self, FollowedSeries.self, Release.self,
            SeriesRecap.self, BookSummary.self, LiteraryEvent.self,
            EventLocationPreference.self, EventSourcePreference.self
        )
        await refresh(context: ModelContext(container), includingWebDiscovery: true)
    }
}

struct RefreshBookBuddyIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Book Buddy"
    static let description = IntentDescription("Refreshes followed releases, Radar, events, and local release reminders.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await BookBuddyRefreshService.refreshFromShortcut()
        return .result(dialog: "Book Buddy is refreshed.")
    }
}

struct BookBuddyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RefreshBookBuddyIntent(),
            phrases: [
                "Refresh \(.applicationName)",
                "Update my books in \(.applicationName)"
            ],
            shortTitle: "Refresh Book Buddy",
            systemImageName: "arrow.clockwise"
        )
    }
}
