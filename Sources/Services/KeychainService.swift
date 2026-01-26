import Foundation
import Security

/// Errors that can occur during Keychain operations.
enum KeychainError: Error, Equatable, LocalizedError {
    /// The item was not found in the Keychain.
    case itemNotFound
    /// Failed to save the item to the Keychain.
    case saveFailed(OSStatus)
    /// Failed to update the existing item in the Keychain.
    case updateFailed(OSStatus)
    /// Failed to delete the item from the Keychain.
    case deleteFailed(OSStatus)
    /// The retrieved data could not be decoded as a string.
    case invalidData

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Token not found in Keychain"
        case let .saveFailed(status):
            return "Failed to save token: \(status)"
        case let .updateFailed(status):
            return "Failed to update token: \(status)"
        case let .deleteFailed(status):
            return "Failed to delete token: \(status)"
        case .invalidData:
            return "Invalid token data in Keychain"
        }
    }
}

/// Service for securely storing and retrieving the Oura API token in the macOS Keychain.
final class KeychainService {
    /// The service name used to identify this app's Keychain items.
    private let service = "com.commander.oura"
    /// The account name for the PAT token.
    private let account = "oura-pat"

    /// Shared instance for convenience.
    static let shared = KeychainService()

    init() {}

    /// Saves the access token to the Keychain.
    /// If a token already exists, it will be updated.
    /// - Parameter token: The personal access token to store.
    /// - Throws: `KeychainError` if the operation fails.
    func saveToken(_ token: String) throws {
        guard let tokenData = token.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        // Check if token already exists
        if (try? retrieveToken()) != nil {
            // Update existing token
            let query = baseQuery()
            let attributes: [String: Any] = [
                kSecValueData as String: tokenData
            ]

            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard status == errSecSuccess else {
                throw KeychainError.updateFailed(status)
            }
        } else {
            // Add new token
            var query = baseQuery()
            query[kSecValueData as String] = tokenData
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked

            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw KeychainError.saveFailed(status)
            }
        }
    }

    /// Retrieves the access token from the Keychain.
    /// - Returns: The stored personal access token.
    /// - Throws: `KeychainError` if the token is not found or data is invalid.
    func retrieveToken() throws -> String {
        var query = baseQuery()
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            throw KeychainError.itemNotFound
        }

        guard status == errSecSuccess else {
            throw KeychainError.itemNotFound
        }

        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return token
    }

    /// Deletes the access token from the Keychain.
    /// - Throws: `KeychainError` if the deletion fails.
    func deleteToken() throws {
        let query = baseQuery()
        let status = SecItemDelete(query as CFDictionary)

        // Don't throw if item wasn't found - that's the desired state
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// Checks if a token exists in the Keychain without retrieving it.
    /// - Returns: `true` if a token is stored, `false` otherwise.
    func hasToken() -> Bool {
        (try? retrieveToken()) != nil
    }

    // MARK: - Private Helpers

    /// Creates the base query dictionary for Keychain operations.
    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
