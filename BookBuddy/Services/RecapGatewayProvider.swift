import Foundation
import Security

struct RecapGatewayConfiguration: Sendable, Equatable {
    let endpoint: URL
    let token: String

    init(endpointString: String, token: String) throws {
        let trimmedEndpoint = endpointString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let endpoint = URL(string: trimmedEndpoint), endpoint.scheme == "https", endpoint.host != nil else {
            throw RecapGatewayConfigurationError.invalidEndpoint
        }
        guard endpoint.path == "/v1/recaps" else {
            throw RecapGatewayConfigurationError.invalidEndpoint
        }
        guard !trimmedToken.isEmpty else {
            throw RecapGatewayConfigurationError.missingToken
        }
        self.endpoint = endpoint
        self.token = trimmedToken
    }
}

enum RecapGatewayConfigurationError: LocalizedError {
    case invalidEndpoint
    case missingToken

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            "Enter the full secure Worker endpoint, ending in /v1/recaps."
        case .missingToken:
            "Enter the app access token you created for the recap gateway."
        }
    }
}

final class RecapGatewayCredentialsStore {
    static let shared = RecapGatewayCredentialsStore()

    private let service = "com.reneemirka.BookBuddy"
    private let account = "recap-gateway-client-token"
    private let endpointKey = "recap-gateway-endpoint"

    func configuration() throws -> RecapGatewayConfiguration? {
        guard let endpoint = UserDefaults.standard.string(forKey: endpointKey), let token = try token() else {
            return nil
        }
        return try RecapGatewayConfiguration(endpointString: endpoint, token: token)
    }

    func save(configuration: RecapGatewayConfiguration) throws {
        try saveToken(configuration.token)
        UserDefaults.standard.set(configuration.endpoint.absoluteString, forKey: endpointKey)
    }

    func removeConfiguration() throws {
        UserDefaults.standard.removeObject(forKey: endpointKey)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialsError.unavailable
        }
    }

    private func token() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data, let token = String(data: data, encoding: .utf8) else {
            throw CredentialsError.unavailable
        }
        return token
    }

    private func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw CredentialsError.unavailable }
        } else if updateStatus != errSecSuccess {
            throw CredentialsError.unavailable
        }
    }

    enum CredentialsError: LocalizedError {
        case unavailable
        var errorDescription: String? { "Book Buddy could not access the secure recap credential." }
    }
}

struct CloudflareRecapProvider: SeriesRecapProvider {
    let configuration: RecapGatewayConfiguration

    func generateRecap(for request: SeriesRecapRequest) async throws -> String {
        try await generate(payload: GatewayRequest(request: request), fingerprint: request.sourceFingerprint)
    }

    fileprivate func generate(payload: GatewayRequest, fingerprint: String) async throws -> String {
        var urlRequest = URLRequest(url: configuration.endpoint)
        urlRequest.httpMethod = "POST"
        // Sourced recaps may take longer than a normal model-only response.
        // Keep the request finite while allowing the gateway to finish search.
        urlRequest.timeoutInterval = 120
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else { throw RecapGatewayError.unavailable }
        switch httpResponse.statusCode {
        case 200...299:
            let payload = try JSONDecoder().decode(GatewayResponse.self, from: data)
            guard payload.sourceFingerprint == fingerprint, !payload.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RecapGenerationError.invalidResponse
            }
            return payload.content
        case 401:
            throw RecapGatewayError.unauthorized
        case 429:
            if let failure = try? JSONDecoder().decode(GatewayFailure.self, from: data), failure.code?.hasPrefix("provider_rate_limited") == true {
                throw RecapGatewayError.providerFailure(failure.code)
            }
            throw RecapGatewayError.quotaReached
        default:
            let failure = try? JSONDecoder().decode(GatewayFailure.self, from: data)
            throw RecapGatewayError.providerFailure(failure?.code)
        }
    }
}

extension CloudflareRecapProvider: BookSummaryProvider {
    func generateBookSummary(for request: BookSummaryRequest) async throws -> String {
        try await generate(
            payload: GatewayRequest(bookSummaryRequest: request),
            fingerprint: request.sourceFingerprint
        )
    }
}

enum RecapGatewayError: LocalizedError {
    case unauthorized
    case quotaReached
    case unavailable
    case providerFailure(String?)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            "Book Buddy could not authorize with the recap gateway. Check the app access token in Settings."
        case .quotaReached:
            "Your recap quota has been reached. Try again later."
        case .unavailable:
            "The recap gateway is temporarily unavailable. Try again later."
        case .providerFailure(let code):
            if code?.hasPrefix("provider_rate_limited") == true {
                "The recap research service is temporarily busy. Please try again in a minute."
            } else if let code {
                "The recap provider rejected the request (\(code))."
            } else {
                "The recap gateway is temporarily unavailable. Try again later."
            }
        }
    }
}

struct LocalBookstoreSearchResult: Decodable, Identifiable {
    enum Availability: String, Decodable, Equatable {
        case listedAvailable = "listed_available"
        case preorderAvailable = "preorder_available"
        case checkWithStore = "check_with_store"

        var title: String {
            switch self {
            case .listedAvailable: "Listed as available"
            case .preorderAvailable: "Preorder available"
            case .checkWithStore: "Check with store"
            }
        }
    }

    let name: String
    let availability: Availability
    let detail: String
    let sourceURL: URL
    let candidateID: String?
    var id: String { sourceURL.absoluteString }
}

struct LocalBookstoreCandidate: Encodable, Identifiable {
    let id: String
    let name: String
    let address: String
    let distanceMiles: Double
}

enum LocalBookstoreSearchPurpose: String, Codable, CaseIterable, Identifiable {
    case availableNow = "available_now"
    case preorder

    var id: String { rawValue }
    var title: String {
        switch self {
        case .availableNow: "Available Now"
        case .preorder: "Preorders"
        }
    }
}

struct LocalBookstoreGatewayProvider {
    let configuration: RecapGatewayConfiguration

    func search(for book: Book, near location: String, candidates: [LocalBookstoreCandidate], purpose: LocalBookstoreSearchPurpose = .availableNow) async throws -> [LocalBookstoreSearchResult] {
        let endpoint = Self.endpoint(for: configuration)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(LocalBookstoreRequest(book: book, location: location, candidates: candidates, purpose: purpose))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw LocalBookstoreSearchError.unavailable }
        switch response.statusCode {
        case 200...299:
            return try JSONDecoder().decode(LocalBookstoreResponse.self, from: data).stores
        case 401:
            throw LocalBookstoreSearchError.unauthorized
        case 429:
            throw LocalBookstoreSearchError.busy
        default:
            throw LocalBookstoreSearchError.unavailable
        }
    }

    static func endpoint(for configuration: RecapGatewayConfiguration) -> URL {
        var components = URLComponents(url: configuration.endpoint, resolvingAgainstBaseURL: false)!
        components.path = "/v1/local-bookstores"
        return components.url!
    }
}

enum LocalBookstoreSearchError: LocalizedError {
    case notConfigured
    case unauthorized
    case busy
    case unavailable
    case noNearbyBookstores

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Connect the recap gateway in Settings before searching local bookstores."
        case .unauthorized:
            "Book Buddy could not authorize with the local bookstore search service. Check the app access token in Settings."
        case .busy:
            "Local bookstore search is temporarily busy. Please try again in a minute."
        case .unavailable:
            "Local bookstore search is temporarily unavailable. Please try again later."
        case .noNearbyBookstores:
            "Book Buddy could not find bookstores near this area. Try a nearby city instead."
        }
    }
}

private struct LocalBookstoreRequest: Encodable {
    let title: String
    let author: String?
    let isbn: String?
    let location: String
    let candidates: [LocalBookstoreCandidate]
    let purpose: LocalBookstoreSearchPurpose

    init(book: Book, location: String, candidates: [LocalBookstoreCandidate], purpose: LocalBookstoreSearchPurpose) {
        title = book.title
        author = book.author?.name
        isbn = book.isbn
        self.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        self.candidates = candidates
        self.purpose = purpose
    }
}

private struct LocalBookstoreResponse: Decodable {
    let stores: [LocalBookstoreSearchResult]
}

private struct GatewayRequest: Encodable {
    let seriesName: String
    let readBooks: [GatewayBook]
    let sourceFingerprint: String
    let recapType: String

    init(request: SeriesRecapRequest) {
        seriesName = request.seriesName
        readBooks = request.readBooks.map(GatewayBook.init)
        sourceFingerprint = request.sourceFingerprint
        recapType = "series"
    }

    init(bookSummaryRequest request: BookSummaryRequest) {
        seriesName = request.bookTitle
        readBooks = [GatewayBook(book: request.sourceBook)]
        sourceFingerprint = request.sourceFingerprint
        recapType = "book"
    }
}

private struct GatewayBook: Encodable {
    let title: String
    let position: Double?
    let rating: Double?
    let review: String?
    let finishedReadingAt: String?

    init(book: RecapSourceBook) {
        title = book.title
        position = book.position
        rating = book.rating
        review = book.review
        finishedReadingAt = book.finishedReadingAt.map { ISO8601DateFormatter().string(from: $0) }
    }
}

private struct GatewayResponse: Decodable {
    let content: String
    let sourceFingerprint: String
}

private struct GatewayFailure: Decodable {
    let code: String?
}
