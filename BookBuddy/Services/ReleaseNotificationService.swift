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
    case oneMonth
    case oneWeek
    case releaseDay

    var title: String {
        switch self {
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
            + ["release.\(release.id.uuidString).threeMonths"]
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

    static func notificationBody(for release: Release, kind: ReleaseReminderKind) -> String {
        let description = releaseDescription(for: release)
        return switch kind {
        case .oneMonth:
            "\(description) is expected in about one month.\(seriesRatingMessage(for: release))"
        case .oneWeek:
            "\(description) releases next week. Open Book Buddy for a spoiler-safe recap of what you need to remember."
        case .releaseDay:
            "\(description) is out today. Open Book Buddy to find it locally."
        }
    }

    private static func releaseDescription(for release: Release) -> String {
        guard let book = release.book else { return "A followed book" }
        let series = book.seriesMemberships.compactMap(\.series).first
        let author = book.author?.name

        var description = book.title
        if let series { description += " from \(series.name)" }
        if let author, !author.isEmpty { description += " by \(author)" }
        return description
    }

    private static func seriesRatingMessage(for release: Release) -> String {
        guard let book = release.book,
              let series = book.seriesMemberships.compactMap(\.series).first
        else { return "" }

        let ratings = series.books
            .compactMap(\.book)
            .filter { $0.id != book.id }
            .flatMap(\.userBooks)
            .filter { $0.readingStatus == .read }
            .compactMap(\.rating)
        guard !ratings.isEmpty else { return "" }

        let average = ratings.reduce(0, +) / Double(ratings.count)
        return " You rated this series \(average.formatted(.number.precision(.fractionLength(1))))★ on average."
    }
}
