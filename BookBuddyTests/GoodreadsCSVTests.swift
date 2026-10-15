import XCTest
@testable import BookBuddy

final class GoodreadsCSVTests: XCTestCase {
    func testParsesGoodreadsReadingFieldsAndQuotedReview() throws {
        let csv = "Book Id,Title,Author,ISBN13,Exclusive Shelf,My Rating,My Review,Date Read,Date Added\n42,\"A, Book\",Ada Author,9780123456789,read,5,\"Loved it, especially the ending.\",2026/09/01,2026/08/20\n"

        let row = try XCTUnwrap(GoodreadsCSV.parse(Data(csv.utf8)).first)

        XCTAssertEqual(row.id, "42")
        XCTAssertEqual(row.title, "A, Book")
        XCTAssertEqual(row.author, "Ada Author")
        XCTAssertEqual(row.isbn, "9780123456789")
        XCTAssertEqual(row.shelf, "read")
        XCTAssertEqual(row.rating, 5)
        XCTAssertEqual(row.review, "Loved it, especially the ending.")
        XCTAssertNotNil(row.dateRead)
        XCTAssertNotNil(row.dateAdded)
    }

    func testTreatsZeroRatingAsUnrated() throws {
        let csv = "Book Id,Title,Author,My Rating\n7,Untitled,Anon,0\n"
        let row = try XCTUnwrap(GoodreadsCSV.parse(Data(csv.utf8)).first)
        XCTAssertNil(row.rating)
    }

    func testRejectsFileWithoutRequiredHeaders() {
        XCTAssertThrowsError(try GoodreadsCSV.parse(Data("Name,Value\nA,B\n".utf8)))
    }

    func testDateFilterSkipsOnlyRecordsWhoseNewestRelevantDatePrecedesCutoff() throws {
        let csv = "Book Id,Title,Author,Date Read,Date Added\n1,Older,A,2019/12/01,2019/12/02\n2,Recent,A,2019/12/01,2020/01/02\n3,Undated,A,,\n"
        let cutoff = try XCTUnwrap(GoodreadsCSV.date("2020/01/01"))
        let filter = GoodreadsImportFilter(earliestActivityDate: cutoff)
        let preview = try GoodreadsImporter().preview(Data(csv.utf8), filter: filter)

        XCTAssertEqual(preview.eligible, 2)
        XCTAssertEqual(preview.skipped, 1)
    }

    func testDateFilterWithoutCutoffIncludesEveryRecord() throws {
        let csv = "Book Id,Title,Author,Date Read\n1,Older,A,2019/12/01\n2,Undated,A,\n"
        let preview = try GoodreadsImporter().preview(Data(csv.utf8))

        XCTAssertEqual(preview.eligible, 2)
        XCTAssertEqual(preview.skipped, 0)
    }
}
