import Foundation
import SwiftData

@Model final class SeriesBook {
    @Attribute(.unique) var id: UUID
    var position: Double?
    var type: String
    var series: Series?
    var book: Book?
    init(id: UUID = UUID(), series: Series? = nil, book: Book? = nil, position: Double? = nil, type: String = "novel") { self.id = id; self.series = series; self.book = book; self.position = position; self.type = type }
}

/// Explicit series numbering is authoritative. When a metadata provider does
/// not supply it, publication year is a more useful fallback than title order.
enum SeriesReadingOrder {
    static func sorted(_ memberships: [SeriesBook]) -> [SeriesBook] {
        memberships.sorted { left, right in
            switch (left.position, right.position) {
            case let (leftPosition?, rightPosition?):
                if leftPosition != rightPosition { return leftPosition < rightPosition }
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                break
            }

            let leftYear = left.book?.firstPublishedYear ?? .max
            let rightYear = right.book?.firstPublishedYear ?? .max
            if leftYear != rightYear { return leftYear < rightYear }
            return (left.book?.title ?? "").localizedCaseInsensitiveCompare(right.book?.title ?? "") == .orderedAscending
        }
    }
}
