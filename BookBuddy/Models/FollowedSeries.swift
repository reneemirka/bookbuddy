import Foundation
import SwiftData

@Model final class FollowedSeries {
    @Attribute(.unique) var id: UUID
    var followedAt: Date
    var notificationsEnabled: Bool
    var series: Series?

    init(id: UUID = UUID(), series: Series? = nil, followedAt: Date = .now, notificationsEnabled: Bool = true) {
        self.id = id
        self.series = series
        self.followedAt = followedAt
        self.notificationsEnabled = notificationsEnabled
    }
}
