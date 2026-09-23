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
