import Foundation
import Security

protocol HardcoverCredentialsStoring {
    func token() throws -> String?
    func save(token: String) throws
    func removeToken() throws
}

final class HardcoverCredentialsStore: HardcoverCredentialsStoring {
    static let shared = HardcoverCredentialsStore()

    private let service = "com.reneemirka.BookBuddy"
    private let account = "hardcover-api-token"

    func token() throws -> String? {
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

    func save(token: String) throws {
        let data = Data(token.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw CredentialsError.unavailable }
        } else if updateStatus != errSecSuccess {
            throw CredentialsError.unavailable
        }
    }

    func removeToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CredentialsError.unavailable }
    }

    enum CredentialsError: LocalizedError {
        case unavailable
        var errorDescription: String? { "Book Buddy could not access the secure Hardcover credential." }
    }
}
