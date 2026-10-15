import Foundation
import SwiftData

@Model final class FollowedAuthor {
    @Attribute(.unique) var id: UUID
    var followedAt: Date
    var notificationsEnabled: Bool
    var author: Author?

    init(id: UUID = UUID(), author: Author? = nil, followedAt: Date = .now, notificationsEnabled: Bool = true) {
        self.id = id
        self.author = author
        self.followedAt = followedAt
        self.notificationsEnabled = notificationsEnabled
    }
}
