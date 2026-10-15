import Foundation
import SwiftData

/// A locally cached, spoiler-bounded recap for one series.
@Model final class SeriesRecap {
    @Attribute(.unique) var id: UUID
    var content: String
    var sourceFingerprint: String
    var generatedAt: Date
    var series: Series?

    init(id: UUID = UUID(), series: Series? = nil, content: String, sourceFingerprint: String, generatedAt: Date = .now) {
        self.id = id
        self.series = series
        self.content = content
        self.sourceFingerprint = sourceFingerprint
        self.generatedAt = generatedAt
    }
}
