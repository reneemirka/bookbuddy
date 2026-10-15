import Foundation
import SwiftData
import UserNotifications

enum ReleaseNotificationPreferences {
    static let releaseRemindersEnabledKey = "releaseRemindersEnabled"

    static var releaseRemindersEnabled: Bool {
        UserDefaults.standard.bool(forKey: releaseRemindersEnabledKey)
    }
}

enum ReleaseReminderKind: String, CaseIterable {
    case threeMonths
    case oneMonth
    case oneWeek
    case releaseDay

    var title: String {
        switch self {
        case .threeMonths: "About three months away"
        case .oneMonth: "About one month away"
        case .oneWeek: "One week away"
        case .releaseDay: "Out today"
        }
    }
}

struct ReleaseReminder: Equatable {
    let identifier: String
    let date: Date
    let kind: ReleaseReminderKind
}

enum ReleaseReminderSchedule {
    static func reminders(for release: Release, now: Date = .now, calendar: Calendar = .current) -> [ReleaseReminder] {
        guard let releaseDate = release.releaseDate else { return [] }
        let base = calendar.dateComponents([.year, .month, .day], from: releaseDate)
        guard let releaseDay = calendar.date(from: base) else { return [] }
        let candidates: [(ReleaseReminderKind, Date?)] = [
            (.threeMonths, calendar.date(byAdding: .month, value: -3, to: releaseDay)),
            (.oneMonth, calendar.date(byAdding: .month, value: -1, to: releaseDay)),
            (.oneWeek, calendar.date(byAdding: .day, value: -7, to: releaseDay)),
            (.releaseDay, releaseDay)
        ]
        return candidates.compactMap { kind, date in
            guard let date, let deliveryDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date), deliveryDate > now else { return nil }
            return ReleaseReminder(identifier: identifier(for: release, kind: kind), date: deliveryDate, kind: kind)
        }
    }

    static func identifier(for release: Release, kind: ReleaseReminderKind) -> String {
        "release.\(release.id.uuidString).\(kind.rawValue)"
    }

    static func allIdentifiers(for release: Release) -> [String] {
        ReleaseReminderKind.allCases.map { identifier(for: release, kind: $0) }
    }
}

enum ReleaseNotificationService {
    static func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    @MainActor
    static func rescheduleAll(context: ModelContext) async {
        let allReleases = (try? context.fetch(FetchDescriptor<Release>())) ?? []
        for release in allReleases { cancelAll(for: release) }
        guard ReleaseNotificationPreferences.releaseRemindersEnabled else { return }
        let relevantBookIDs = Set(ReleaseTrackingService.relevantBooks(context: context).map(\.id))
        let activeReleases = allReleases.filter { release in
            guard let book = release.book, relevantBookIDs.contains(book.id) else { return false }
            return !book.userBooks.contains { $0.readingStatus == .read }
        }
        await schedule(releases: activeReleases)
    }

    static func schedule(releases: [Release], now: Date = .now, center: UNUserNotificationCenter = .current()) async {
        for release in releases {
            for reminder in ReleaseReminderSchedule.reminders(for: release, now: now) {
                let content = UNMutableNotificationContent()
                content.title = reminder.kind.title
                content.body = notificationBody(for: release, kind: reminder.kind)
                content.sound = .default
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
                let request = UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
                try? await center.add(request)
            }
        }
    }

    static func cancelAll(for release: Release, center: UNUserNotificationCenter = .current()) {
        center.removePendingNotificationRequests(withIdentifiers: ReleaseReminderSchedule.allIdentifiers(for: release))
    }

    private static func notificationBody(for release: Release, kind: ReleaseReminderKind) -> String {
        let title = release.book?.title ?? "A followed book"
        return switch kind {
        case .threeMonths: "\(title) is expected in about three months."
        case .oneMonth: "\(title) is expected in about one month."
        case .oneWeek: "\(title) is expected next week."
        case .releaseDay: "\(title) is out today."
        }
    }
}
