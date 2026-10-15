import XCTest
import SwiftData
@testable import BookBuddy

final class ReleaseNotificationServiceTests: XCTestCase {
    func testCreatesFourStableRemindersForAFutureRelease() {
        let release = Release(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, releaseDate: date("2027-06-15"), status: .upcoming, source: "Test", confidence: .confirmed)

        let reminders = ReleaseReminderSchedule.reminders(for: release, now: date("2027-01-01"))

        XCTAssertEqual(reminders.map(\.kind), [.threeMonths, .oneMonth, .oneWeek, .releaseDay])
        XCTAssertEqual(reminders.map(\.identifier), [
            "release.00000000-0000-0000-0000-000000000001.threeMonths",
            "release.00000000-0000-0000-0000-000000000001.oneMonth",
            "release.00000000-0000-0000-0000-000000000001.oneWeek",
            "release.00000000-0000-0000-0000-000000000001.releaseDay"
        ])
    }

    func testExcludesElapsedReminderDates() {
        let release = Release(releaseDate: date("2027-06-15"), status: .upcoming, source: "Test")

        let reminders = ReleaseReminderSchedule.reminders(for: release, now: date("2027-05-20"))

        XCTAssertEqual(reminders.map(\.kind), [.oneWeek, .releaseDay])
    }

    private func date(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: "\(string)T00:00:00Z")!
    }
}
