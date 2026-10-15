import Foundation

struct HardcoverProvider: ReadingDataProvider {
    let name = "Hardcover"
    private let token: String
    private let session: URLSession

    init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }

    func fetchReadingHistory() async throws -> [ReadingDataRecord] {
        let query = """
        query BookBuddyReadingHistory {
          me {
            user_books(order_by: { updated_at: asc }) {
              id
              status_id
              rating
              review_raw
              date_added
              book {
                title
                subtitle
                isbns
                contributions { author { name } }
              }
              user_book_reads(order_by: { id: desc }, limit: 1) {
                started_at
                finished_at
              }
            }
          }
        }
        """
        var request = URLRequest(url: URL(string: "https://api.hardcover.app/v1/graphql")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("BookBuddy/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue(token.lowercased().hasPrefix("bearer ") ? token : "Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(GraphQLRequest(query: query))

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 { throw ReadingDataProviderError.unauthorized }
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else { throw ReadingDataProviderError.invalidResponse }
        let decoded = try JSONDecoder.hardcover.decode(GraphQLResponse.self, from: data)
        if let message = decoded.errors?.first?.message { throw ReadingDataProviderError.remote(message: message) }
        guard let records = decoded.data?.me.flatMap(\.userBooks) else { throw ReadingDataProviderError.invalidResponse }
        return records.map { record in
            ReadingDataRecord(
                id: String(record.id),
                title: record.book.title,
                subtitle: record.book.subtitle,
                authorName: record.book.contributions.first?.author.name,
                isbn: record.book.isbns.first,
                status: Self.status(for: record.statusID),
                rating: record.rating,
                review: record.review?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                startedReadingAt: record.reads.first?.startedAt,
                finishedReadingAt: record.reads.first?.finishedAt,
                addedAt: record.addedAt
            )
        }
    }

    private static func status(for id: Int) -> ReadingStatus {
        switch id {
        case 2: return .currentlyReading
        case 3: return .read
        case 5: return .didNotFinish
        default: return .wantToRead
        }
    }
}

private struct GraphQLRequest: Encodable { let query: String }
private struct GraphQLResponse: Decodable { let data: HardcoverData?; let errors: [GraphQLError]? }
private struct GraphQLError: Decodable { let message: String }
private struct HardcoverData: Decodable { let me: [HardcoverMe] }
private struct HardcoverMe: Decodable { let userBooks: [HardcoverUserBook] }
private struct HardcoverUserBook: Decodable {
    let id: Int
    let statusID: Int
    let rating: Double?
    let review: String?
    let addedAt: Date?
    let book: HardcoverBook
    let reads: [HardcoverRead]
    enum CodingKeys: String, CodingKey { case id, rating, book; case statusID = "status_id"; case review = "review_raw"; case addedAt = "date_added"; case reads = "user_book_reads" }
}
private struct HardcoverBook: Decodable { let title: String; let subtitle: String?; let isbns: [String]; let contributions: [HardcoverContribution] }
private struct HardcoverContribution: Decodable { let author: HardcoverAuthor }
private struct HardcoverAuthor: Decodable { let name: String }
private struct HardcoverRead: Decodable { let startedAt: Date?; let finishedAt: Date?; enum CodingKeys: String, CodingKey { case startedAt = "started_at"; case finishedAt = "finished_at" } }
private extension JSONDecoder {
    static let hardcover: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
