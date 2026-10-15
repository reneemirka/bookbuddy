import Foundation
import Security
import SwiftData

struct MonitoringGatewayConfiguration: Sendable, Equatable {
    let endpoint: URL
    let token: String

    init(endpointString: String, token: String) throws {
        let endpointString = endpointString.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let endpoint = URL(string: endpointString), endpoint.scheme == "https", endpoint.host != nil, endpoint.path == "/v1/monitor/subscriptions" else { throw MonitoringGatewayError.invalidEndpoint }
        guard !token.isEmpty else { throw MonitoringGatewayError.missingToken }
        self.endpoint = endpoint; self.token = token
    }

    var discoveryEndpoint: URL {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.path = "/v1/monitor/discoveries"
        return components.url!
    }
}

enum MonitoringGatewayError: LocalizedError {
    case invalidEndpoint, missingToken, unavailable, unauthorized
    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: "Enter the full secure Worker endpoint, ending in /v1/monitor/subscriptions."
        case .missingToken: "Enter the monitoring Worker access token."
        case .unavailable: "The monitoring service is temporarily unavailable."
        case .unauthorized: "Book Buddy could not authorize with the monitoring service."
        }
    }
}

final class MonitoringGatewayCredentialsStore {
    static let shared = MonitoringGatewayCredentialsStore()
    private let service = "com.reneemirka.BookBuddy"
    private let account = "monitoring-gateway-client-token"
    private let endpointKey = "monitoring-gateway-endpoint"

    func configuration() throws -> MonitoringGatewayConfiguration? {
        guard let endpoint = UserDefaults.standard.string(forKey: endpointKey), let token = try secureToken() else { return nil }
        return try MonitoringGatewayConfiguration(endpointString: endpoint, token: token)
    }
    func save(_ configuration: MonitoringGatewayConfiguration) throws { try saveToken(configuration.token); UserDefaults.standard.set(configuration.endpoint.absoluteString, forKey: endpointKey) }
    func remove() throws { UserDefaults.standard.removeObject(forKey: endpointKey); let status = SecItemDelete(query as CFDictionary); guard status == errSecSuccess || status == errSecItemNotFound else { throw MonitoringGatewayError.unavailable } }

    private var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account] }
    private func secureToken() throws -> String? { var item: CFTypeRef?; var request = query; request[kSecReturnData as String] = true; request[kSecMatchLimit as String] = kSecMatchLimitOne; let status = SecItemCopyMatching(request as CFDictionary, &item); if status == errSecItemNotFound { return nil }; guard status == errSecSuccess, let data = item as? Data, let token = String(data: data, encoding: .utf8) else { throw MonitoringGatewayError.unavailable }; return token }
    private func saveToken(_ token: String) throws { let data = Data(token.utf8); let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary); if status == errSecItemNotFound { var item = query; item[kSecValueData as String] = data; item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly; guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw MonitoringGatewayError.unavailable } } else if status != errSecSuccess { throw MonitoringGatewayError.unavailable } }
}

enum MonitoringSubscriptionService {
    static let deviceIdentifierKey = "monitoring-device-identifier"
    static let deviceTokenKey = "monitoring-apns-device-token"

    static func saveDeviceToken(_ token: Data) { UserDefaults.standard.set(token.map { String(format: "%02.2hhx", $0) }.joined(), forKey: deviceTokenKey) }

    @MainActor static func sync(context: ModelContext) async throws {
        guard let configuration = try MonitoringGatewayCredentialsStore.shared.configuration() else { return }
        let token = UserDefaults.standard.string(forKey: deviceTokenKey)
        let deviceIdentifier = identifier()
        let entities = entities(context: context)
        let eventSources = ((try? context.fetch(FetchDescriptor<EventSourcePreference>())) ?? []).filter(\.isEnabled).compactMap { source -> MonitoringEventSource? in
            guard let url = URL(string: source.feedURL), url.scheme == "https" else { return nil }
            return MonitoringEventSource(name: source.name, feedURL: url.absoluteString)
        }
        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "PUT"; request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(MonitoringSubscription(deviceIdentifier: deviceIdentifier, deviceToken: token, entities: entities, eventSources: eventSources))
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw MonitoringGatewayError.unavailable }
        if response.statusCode == 401 { throw MonitoringGatewayError.unauthorized }
        guard 200..<300 ~= response.statusCode else { throw MonitoringGatewayError.unavailable }
    }

    /// Performs one bounded web-research request for all followed authors and
    /// series, then stores only discoveries with a cited public source.
    @MainActor static func refreshDiscoveries(context: ModelContext) async throws -> Int {
        guard let configuration = try MonitoringGatewayCredentialsStore.shared.configuration() else { return 0 }
        var request = URLRequest(url: configuration.discoveryEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(MonitoringDiscoveryRequest(entities: entities(context: context)))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw MonitoringGatewayError.unavailable }
        if response.statusCode == 401 { throw MonitoringGatewayError.unauthorized }
        guard 200..<300 ~= response.statusCode else { throw MonitoringGatewayError.unavailable }
        let discoveries = try JSONDecoder().decode(MonitoringDiscoveryResponse.self, from: data).discoveries
        return store(discoveries, context: context)
    }

    @MainActor private static func entities(context: ModelContext) -> [MonitoringEntity] {
        var values: [MonitoringEntity] = []
        let books = ((try? context.fetch(FetchDescriptor<FollowedBook>())) ?? []).compactMap(\.book)
        values += books.map { MonitoringEntity(kind: .book, id: $0.openLibraryWorkID ?? $0.isbn ?? $0.id.uuidString, title: $0.title, author: $0.author?.name) }
        let authors = ((try? context.fetch(FetchDescriptor<FollowedAuthor>())) ?? []).compactMap(\.author)
        values += authors.map { MonitoringEntity(kind: .author, id: $0.id.uuidString, title: $0.name, author: nil) }
        let series = ((try? context.fetch(FetchDescriptor<FollowedSeries>())) ?? []).compactMap(\.series)
        values += series.map { MonitoringEntity(kind: .series, id: $0.id.uuidString, title: $0.name, author: $0.authors.first?.name) }
        return Array(Dictionary(uniqueKeysWithValues: values.map { ("\($0.kind.rawValue):\($0.id)", $0) }).values)
    }

    @MainActor private static func store(_ discoveries: [MonitoringDiscovery], context: ModelContext) -> Int {
        let followedSeries = ((try? context.fetch(FetchDescriptor<FollowedSeries>())) ?? []).compactMap(\.series)
        var stored = 0
        for discovery in discoveries {
            let series = followedSeries.first { $0.name.caseInsensitiveCompare(discovery.seriesName) == .orderedSame }
            let result = BookSearchResult(
                id: "web-discovery-\(discovery.sourceURL)",
                title: discovery.title,
                subtitle: nil,
                authorName: discovery.authorName,
                isbn: nil,
                seriesName: discovery.seriesName.isEmpty ? nil : discovery.seriesName,
                firstPublishedYear: year(in: discovery.releaseDate),
                coverID: nil
            )
            let book = series.map { SearchLibraryService.cache(result, in: $0, context: context) }
                ?? SearchLibraryService.cache(result, context: context)
            guard let releaseDate = releaseDate(discovery.releaseDate) else { continue }
            if let release = ReleaseTrackingService.release(for: book, context: context) {
                guard release.confidence != .confirmed else { continue }
                release.releaseDate = releaseDate
                release.statusRawValue = ReleaseStatus.upcoming.rawValue
                release.source = discovery.sourceTitle
                release.sourceURL = discovery.sourceURL
                release.confidenceRawValue = ReleaseConfidence.likely.rawValue
                release.lastChecked = .now
            } else {
                context.insert(Release(book: book, releaseDate: releaseDate, status: .upcoming, source: discovery.sourceTitle, sourceURL: discovery.sourceURL, confidence: .likely))
            }
            stored += 1
        }
        try? context.save()
        return stored
    }

    private static func releaseDate(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: "\(value)T00:00:00Z")
    }

    private static func year(in value: String) -> Int? {
        Int(value.prefix(4))
    }
    private static func identifier() -> String { if let value = UserDefaults.standard.string(forKey: deviceIdentifierKey) { return value }; let value = UUID().uuidString; UserDefaults.standard.set(value, forKey: deviceIdentifierKey); return value }
}

extension Notification.Name { static let monitoringPreferencesChanged = Notification.Name("monitoringPreferencesChanged") }

private struct MonitoringSubscription: Encodable { let deviceIdentifier: String; let deviceToken: String?; let entities: [MonitoringEntity]; let eventSources: [MonitoringEventSource] }
private struct MonitoringEntity: Encodable { enum Kind: String, Encodable { case book, author, series }; let kind: Kind; let id: String; let title: String; let author: String? }
private struct MonitoringEventSource: Encodable { let name: String; let feedURL: String }
private struct MonitoringDiscoveryRequest: Encodable { let entities: [MonitoringEntity] }
private struct MonitoringDiscoveryResponse: Decodable { let discoveries: [MonitoringDiscovery] }
private struct MonitoringDiscovery: Decodable { let title: String; let authorName: String; let seriesName: String; let releaseDate: String; let sourceTitle: String; let sourceURL: String }
