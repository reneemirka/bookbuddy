import XCTest

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
}
