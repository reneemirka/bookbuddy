import XCTest
import SwiftData
@testable import BookBuddy

final class ReleaseNotificationServiceTests: XCTestCase {
    func testCreatesThreeStableRemindersForAFutureRelease() {
        let release = Release(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, releaseDate: date("2027-06-15"), status: .upcoming, source: "Test", confidence: .confirmed)

        let reminders = ReleaseReminderSchedule.reminders(for: release, now: date("2027-01-01"))

        XCTAssertEqual(reminders.map(\.kind), [.oneMonth, .oneWeek, .releaseDay])
        XCTAssertEqual(reminders.map(\.identifier), [
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

    func testOneMonthReminderIncludesSeriesAndPersonalRating() {
        let author = Author(name: "A. Writer")
        let series = Series(name: "The Moon Books")
        let previousBook = Book(title: "Moon One", author: author)
        let upcomingBook = Book(title: "Moon Two", author: author)
        let previousMembership = SeriesBook(series: series, book: previousBook, position: 1)
        let upcomingMembership = SeriesBook(series: series, book: upcomingBook, position: 2)
        let reading = UserBook(book: previousBook, readingStatus: .read, rating: 4.5)
        let release = Release(book: upcomingBook, releaseDate: date("2027-06-15"), status: .upcoming, source: "Test")

        // Keep strong references to relationship objects for the duration of the assertion.
        _ = [previousMembership, upcomingMembership, reading]

        XCTAssertEqual(
            ReleaseNotificationService.notificationBody(for: release, kind: .oneMonth),
            "Moon Two from The Moon Books by A. Writer is expected in about one month. You rated this series 4.5★ on average."
        )
    }

    private func date(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: "\(string)T00:00:00Z")!
    }
}
