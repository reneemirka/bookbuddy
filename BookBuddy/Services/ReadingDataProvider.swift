import Foundation

struct ReadingDataRecord: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let authorName: String?
    let isbn: String?
    let status: ReadingStatus
    let rating: Double?
    let review: String?
    let startedReadingAt: Date?
    let finishedReadingAt: Date?
    let addedAt: Date?
}

protocol ReadingDataProvider: Sendable {
    var name: String { get }
    func fetchReadingHistory() async throws -> [ReadingDataRecord]
}

enum ReadingDataProviderError: LocalizedError {
    case notConnected
    case invalidResponse
    case unauthorized
    case remote(message: String)

    var errorDescription: String? {
        switch self {
        case .notConnected: "Connect a reading service before syncing."
        case .invalidResponse: "The reading service returned an unexpected response."
        case .unauthorized: "Your Hardcover token is invalid or has expired."
        case .remote(let message): message
        }
    }
}
