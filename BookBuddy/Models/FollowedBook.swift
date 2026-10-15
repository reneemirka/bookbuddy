import Foundation
import SwiftData

@Model final class FollowedBook {
    @Attribute(.unique) var id: UUID
    var followedAt: Date
    var notificationsEnabled: Bool
    var book: Book?

    init(id: UUID = UUID(), book: Book? = nil, followedAt: Date = .now, notificationsEnabled: Bool = true) {
        self.id = id
        self.book = book
        self.followedAt = followedAt
        self.notificationsEnabled = notificationsEnabled
    }
}
