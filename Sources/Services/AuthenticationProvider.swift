import Foundation

/// Represents the type of authentication being used.
enum AuthenticationType: String, Codable {
    /// Personal Access Token (PAT) authentication.
    /// Users manually generate and provide a token from the Oura developer portal.
    case personalAccessToken

    /// OAuth2 authentication (future support).
    /// Uses standard OAuth2 authorization code flow with token refresh.
    case oauth2
}

/// Represents the result of an authentication operation.
enum AuthenticationResult {
    /// Authentication was successful with the provided token.
    case success(token: String)
    /// Authentication failed with the specified error.
    case failure(AuthenticationError)
    /// Token needs to be refreshed (OAuth2 only).
    case needsRefresh
}

/// Errors that can occur during authentication operations.
enum AuthenticationError: Error, LocalizedError {
    /// No credentials are configured.
    case notConfigured
    /// The stored credentials are invalid.
    case invalidCredentials
    /// Token refresh failed (OAuth2 only).
    case refreshFailed(String)
    /// The OAuth2 authorization was denied by the user.
    case authorizationDenied
    /// Network error during authentication.
    case networkError(String)
    /// Keychain storage error.
    case storageError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Authentication is not configured"
        case .invalidCredentials:
            return "Invalid or expired credentials"
        case let .refreshFailed(reason):
            return "Token refresh failed: \(reason)"
        case .authorizationDenied:
            return "Authorization was denied"
        case let .networkError(details):
            return "Network error: \(details)"
        case let .storageError(details):
            return "Storage error: \(details)"
        }
    }
}

// MARK: - Authentication Provider Protocol

/// Protocol defining the contract for authentication providers.
/// This abstraction allows the app to support multiple authentication methods
/// (PAT, OAuth2) with a unified interface.
///
/// ## Usage
/// The API service uses this protocol to obtain access tokens without needing
/// to know the underlying authentication mechanism. This enables:
/// - Easy swapping between PAT and OAuth2 authentication
/// - Future support for additional authentication methods
/// - Testability through mock implementations
///
/// ## Implementation Notes
/// - PAT implementation: Simply retrieves the stored token from Keychain
/// - OAuth2 implementation (future): Handles authorization flow and token refresh
protocol AuthenticationProvider {
    /// The type of authentication this provider implements.
    var authenticationType: AuthenticationType { get }

    /// Whether credentials are currently configured.
    var isConfigured: Bool { get }

    /// Retrieves the current access token.
    /// For OAuth2, this may trigger a token refresh if the current token is expired.
    /// - Returns: The authentication result with token or error.
    func getAccessToken() async -> AuthenticationResult

    /// Clears all stored credentials.
    /// - Throws: `AuthenticationError.storageError` if clearing fails.
    func clearCredentials() throws

    /// Refreshes the access token if supported by the authentication type.
    /// - Returns: The authentication result with new token or error.
    /// - Note: For PAT authentication, this always returns `.needsRefresh` as PATs cannot be refreshed.
    func refreshToken() async -> AuthenticationResult
}

// MARK: - PAT Authentication Provider

/// Authentication provider for Personal Access Token (PAT) authentication.
/// This is the current authentication method used by the app.
final class PATAuthenticationProvider: AuthenticationProvider {
    private let keychainService: KeychainService

    let authenticationType: AuthenticationType = .personalAccessToken

    var isConfigured: Bool {
        keychainService.hasToken()
    }

    init(keychainService: KeychainService = .shared) {
        self.keychainService = keychainService
    }

    func getAccessToken() async -> AuthenticationResult {
        do {
            let token = try keychainService.retrieveToken()
            return .success(token: token)
        } catch KeychainError.itemNotFound {
            return .failure(.notConfigured)
        } catch {
            return .failure(.storageError(error.localizedDescription))
        }
    }

    func clearCredentials() throws {
        do {
            try keychainService.deleteToken()
        } catch {
            throw AuthenticationError.storageError(error.localizedDescription)
        }
    }

    func refreshToken() async -> AuthenticationResult {
        // PAT tokens cannot be refreshed - user must generate a new one
        .needsRefresh
    }

    /// Saves a new Personal Access Token.
    /// - Parameter token: The PAT to store.
    /// - Throws: `AuthenticationError.storageError` if saving fails.
    func saveToken(_ token: String) throws {
        do {
            try keychainService.saveToken(token)
        } catch {
            throw AuthenticationError.storageError(error.localizedDescription)
        }
    }
}

// MARK: - OAuth2 Configuration (Future Support)

/// Configuration for OAuth2 authentication.
/// This structure holds the OAuth2 application credentials needed for the authorization flow.
///
/// ## Future Implementation
/// When OAuth2 support is added, this configuration will be used to:
/// 1. Build the authorization URL for the user to approve access
/// 2. Exchange the authorization code for access/refresh tokens
/// 3. Refresh expired access tokens automatically
struct OAuth2Configuration {
    /// The OAuth2 client ID from the Oura developer portal.
    let clientId: String

    /// The OAuth2 client secret from the Oura developer portal.
    /// Note: For native apps, consider using PKCE instead of client secrets.
    let clientSecret: String

    /// The redirect URI registered with Oura.
    /// Default: `commander://oauth/callback`
    let redirectURI: String

    /// The OAuth2 scopes to request.
    let scopes: [String]

    /// Oura OAuth2 authorization endpoint.
    static let authorizationURL = "https://cloud.ouraring.com/oauth/authorize"

    /// Oura OAuth2 token endpoint.
    static let tokenURL = "https://cloud.ouraring.com/oauth/token"

    /// Default redirect URI for the Commander app.
    static let defaultRedirectURI = "commander://oauth/callback"

    /// Default scopes needed for the app's functionality.
    static let defaultScopes = ["daily", "heartrate", "personal"]

    /// Creates a configuration with the default redirect URI and scopes.
    /// - Parameters:
    ///   - clientId: The OAuth2 client ID.
    ///   - clientSecret: The OAuth2 client secret.
    init(clientId: String, clientSecret: String) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.redirectURI = Self.defaultRedirectURI
        self.scopes = Self.defaultScopes
    }

    /// Creates a configuration with custom redirect URI and scopes.
    /// - Parameters:
    ///   - clientId: The OAuth2 client ID.
    ///   - clientSecret: The OAuth2 client secret.
    ///   - redirectURI: Custom redirect URI.
    ///   - scopes: Custom OAuth2 scopes.
    init(clientId: String, clientSecret: String, redirectURI: String, scopes: [String]) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
        self.scopes = scopes
    }
}

// MARK: - OAuth2 Token Response (Future Support)

/// Response structure for OAuth2 token requests.
/// Used when exchanging authorization codes or refreshing tokens.
struct OAuth2TokenResponse: Codable {
    /// The access token for API requests.
    let accessToken: String

    /// The refresh token for obtaining new access tokens.
    let refreshToken: String?

    /// Token lifetime in seconds.
    let expiresIn: Int

    /// The type of token (typically "Bearer").
    let tokenType: String

    /// The granted scopes (space-separated).
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
    }
}

// MARK: - OAuth2 Stored Credentials (Future Support)

/// Stored OAuth2 credentials including expiration tracking.
/// This structure is serialized to Keychain for persistent storage.
struct OAuth2Credentials: Codable {
    /// The access token for API requests.
    let accessToken: String

    /// The refresh token for obtaining new access tokens.
    let refreshToken: String

    /// The timestamp when the access token expires.
    let expiresAt: Date

    /// The granted scopes.
    let scopes: [String]

    /// Whether the access token has expired.
    var isExpired: Bool {
        Date() >= expiresAt
    }

    /// Whether the access token will expire soon (within 5 minutes).
    var willExpireSoon: Bool {
        Date().addingTimeInterval(300) >= expiresAt
    }
}

// MARK: - OAuth2 Authentication Provider Placeholder

/// Placeholder for OAuth2 authentication provider.
/// This class provides the structure for future OAuth2 implementation.
///
/// ## Implementation Roadmap
/// 1. Implement `startAuthorizationFlow()` to open browser with authorization URL
/// 2. Handle the callback URL scheme (`commander://oauth/callback`)
/// 3. Exchange authorization code for tokens via `handleCallback()`
/// 4. Store tokens securely in Keychain
/// 5. Implement automatic token refresh in `getAccessToken()`
///
/// ## Required App Changes for OAuth2
/// - Register URL scheme in Info.plist
/// - Add ASWebAuthenticationSession for secure browser auth
/// - Update AppDelegate to handle URL callbacks
final class OAuth2AuthenticationProvider: AuthenticationProvider {
    private let keychainService: KeychainService
    private let configuration: OAuth2Configuration?

    let authenticationType: AuthenticationType = .oauth2

    /// Keychain account for storing OAuth2 credentials.
    private let oauth2Account = "oura-oauth2"

    var isConfigured: Bool {
        configuration != nil && loadStoredCredentials() != nil
    }

    init(configuration: OAuth2Configuration? = nil, keychainService: KeychainService = .shared) {
        self.configuration = configuration
        self.keychainService = keychainService
    }

    func getAccessToken() async -> AuthenticationResult {
        guard let credentials = loadStoredCredentials() else {
            return .failure(.notConfigured)
        }

        if credentials.isExpired || credentials.willExpireSoon {
            return await refreshToken()
        }

        return .success(token: credentials.accessToken)
    }

    func clearCredentials() throws {
        // Future: Clear OAuth2 credentials from Keychain
        // For now, this is a placeholder
    }

    func refreshToken() async -> AuthenticationResult {
        guard let credentials = loadStoredCredentials(),
              configuration != nil else {
            return .failure(.notConfigured)
        }

        // Future: Implement actual token refresh
        // For now, return failure indicating refresh is needed
        _ = credentials.refreshToken
        return .failure(.refreshFailed("OAuth2 not yet implemented"))
    }

    // MARK: - Private Helpers

    private func loadStoredCredentials() -> OAuth2Credentials? {
        // Future: Load OAuth2 credentials from Keychain
        // For now, return nil as OAuth2 is not yet implemented
        nil
    }

    // MARK: - Future Implementation Stubs

    /// Starts the OAuth2 authorization flow.
    /// Opens the system browser to the Oura authorization page.
    /// - Throws: `AuthenticationError` if configuration is missing.
    func startAuthorizationFlow() async throws {
        guard let config = configuration else {
            throw AuthenticationError.notConfigured
        }

        // Future: Build authorization URL and open in browser
        // let authURL = buildAuthorizationURL(config: config)
        // await ASWebAuthenticationSession(...)
        _ = config
    }

    /// Handles the OAuth2 callback from the authorization flow.
    /// - Parameter url: The callback URL containing the authorization code.
    /// - Returns: Authentication result with access token or error.
    func handleCallback(url: URL) async -> AuthenticationResult {
        // Future: Extract authorization code and exchange for tokens
        _ = url
        return .failure(.notConfigured)
    }
}

// MARK: - Authentication Manager

/// Central manager for authentication, providing access to the current authentication provider.
/// This class allows the app to switch between authentication methods seamlessly.
final class AuthenticationManager {
    /// Shared instance for app-wide authentication management.
    static let shared = AuthenticationManager()

    /// The current authentication provider.
    private(set) var currentProvider: AuthenticationProvider

    /// The type of authentication currently in use.
    var authenticationType: AuthenticationType {
        currentProvider.authenticationType
    }

    /// Whether authentication is configured.
    var isConfigured: Bool {
        currentProvider.isConfigured
    }

    init() {
        // Default to PAT authentication
        self.currentProvider = PATAuthenticationProvider()
    }

    /// Switches to a different authentication provider.
    /// - Parameter provider: The new authentication provider to use.
    func switchProvider(_ provider: AuthenticationProvider) {
        self.currentProvider = provider
    }

    /// Convenience method to get the current access token.
    /// - Returns: The authentication result with token or error.
    func getAccessToken() async -> AuthenticationResult {
        await currentProvider.getAccessToken()
    }

    /// Clears credentials from the current provider.
    func clearCredentials() throws {
        try currentProvider.clearCredentials()
    }
}
