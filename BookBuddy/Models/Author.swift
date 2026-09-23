import Foundation
import SwiftData

@Model final class Author {
    @Attribute(.unique) var id: UUID
    var name: String
    @Relationship(inverse: \Book.author) var books: [Book] = []
    @Relationship(inverse: \Series.authors) var series: [Series] = []
    init(id: UUID = UUID(), name: String) { self.id = id; self.name = name }
}
