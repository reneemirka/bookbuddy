import Foundation
import NaturalLanguage

struct BookSearchResult: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let authorName: String?
    let isbn: String?
    let seriesName: String?
    let firstPublishedYear: Int?
    let coverID: Int?
}

protocol BookMetadataProvider {
    func search(query: String) async throws -> [BookSearchResult]
}

enum BookSearchError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Book search returned an unexpected response."
        }
    }
}

struct OpenLibraryMetadataProvider: BookMetadataProvider {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String) async throws -> [BookSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        var components = URLComponents(string: "https://openlibrary.org/search.json")!
        let isISBN = trimmedQuery.allSatisfy(\.isNumber) && [10, 13].contains(trimmedQuery.count)
        components.queryItems = [
            URLQueryItem(name: isISBN ? "isbn" : "q", value: trimmedQuery),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "fields", value: "key,title,subtitle,author_name,isbn,series,subject,first_publish_year,cover_i")
        ]
        guard let url = components.url else { throw BookSearchError.invalidResponse }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw BookSearchError.invalidResponse
        }
        return try JSONDecoder().decode(Response.self, from: data).docs.map { document in
            BookSearchResult(
                id: document.key,
                title: document.title,
                subtitle: document.subtitle,
                authorName: document.authorNames?.first,
                isbn: document.isbns?.first,
                seriesName: document.series?.first ?? seriesName(from: document.subjects),
                firstPublishedYear: document.firstPublishedYear,
                coverID: document.coverID
            )
        }
    }

    /// Fetches the work-level description used on the local Book Details screen.
    /// Work IDs originate from this provider's search results and are persisted locally.
    func description(forWorkID workID: String) async throws -> String? {
        guard workID.hasPrefix("/works/"), let url = URL(string: "https://openlibrary.org\(workID).json") else {
            throw BookSearchError.invalidResponse
        }
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw BookSearchError.invalidResponse
        }
        return try description(from: data)
    }

    func description(from data: Data) throws -> String? {
        let response = try JSONDecoder().decode(WorkResponse.self, from: data)
        let value = response.description?.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else { return nil }
        return isEnglishDescription(value) ? value : nil
    }

    /// Open Library sometimes supplies the work description in a language other
    /// than the reader's app language. Keep an undetermined short description,
    /// but avoid presenting a confidently non-English one as the default.
    func isEnglishDescription(_ value: String) -> Bool {
        guard value.count >= 40, let language = NLLanguageRecognizer.dominantLanguage(for: value) else {
            return true
        }
        return language == .english
    }

    /// Open Library currently exposes many work-to-series relationships as subjects,
        /// such as `Serie:The_Empyrean`, rather than in its optional `series` field.
    func seriesName(from subjects: [String]?) -> String? {
        guard let subject = subjects?.first(where: {
            $0.lowercased().hasPrefix("series:") || $0.lowercased().hasPrefix("serie:")
        }) else { return nil }
        guard let separator = subject.firstIndex(of: ":") else { return nil }
        let name = subject[subject.index(after: separator)...]
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private struct Response: Decodable {
        let docs: [Document]
    }

    private struct WorkResponse: Decodable {
        let description: Description?
    }

    private enum Description: Decodable {
        case text(String)
        case object(value: String)

        var value: String {
            switch self {
            case .text(let value), .object(let value): value
            }
        }

        init(from decoder: Decoder) throws {
            if let value = try? decoder.singleValueContainer().decode(String.self) {
                self = .text(value)
                return
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self = .object(value: try container.decode(String.self, forKey: .value))
        }

        private enum CodingKeys: String, CodingKey { case value }
    }

    private struct Document: Decodable {
        let key: String
        let title: String
        let subtitle: String?
        let authorNames: [String]?
        let isbns: [String]?
        let series: [String]?
        let subjects: [String]?
        let firstPublishedYear: Int?
        let coverID: Int?

        enum CodingKeys: String, CodingKey {
            case key, title, subtitle, series
            case subjects = "subject"
            case authorNames = "author_name"
            case isbns = "isbn"
            case firstPublishedYear = "first_publish_year"
            case coverID = "cover_i"
        }
    }
}
