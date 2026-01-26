import Foundation

/// Typed errors for Oura API operations.
/// Provides specific error cases for common API failure scenarios.
enum OuraAPIError: Error, Equatable {
    /// The API access token is missing or not configured.
    case missingAccessToken
    /// The constructed URL is invalid.
    case invalidURL
    /// HTTP error with status code and optional message.
    case httpError(statusCode: Int, message: String?)
    /// The access token is invalid or expired (401).
    case unauthorized
    /// Rate limit exceeded (429).
    case rateLimitExceeded
    /// The requested resource was not found (404).
    case notFound
    /// Failed to decode the API response.
    case decodingError(String)
    /// Network connectivity or other URLSession errors.
    case networkError(String)
    /// Server error (5xx status codes).
    case serverError(statusCode: Int)
}

// MARK: - Error Descriptions

extension OuraAPIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingAccessToken:
            return "Oura API access token is not configured"
        case .invalidURL:
            return "Failed to construct a valid API URL"
        case let .httpError(statusCode, message):
            if let message {
                return "HTTP error \(statusCode): \(message)"
            }
            return "HTTP error \(statusCode)"
        case .unauthorized:
            return "Invalid or expired access token"
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please try again later"
        case .notFound:
            return "The requested resource was not found"
        case let .decodingError(details):
            return "Failed to decode API response: \(details)"
        case let .networkError(details):
            return "Network error: \(details)"
        case let .serverError(statusCode):
            return "Server error (\(statusCode)). Please try again later"
        }
    }
}

// MARK: - API Response Wrappers

/// Generic wrapper for paginated Oura API responses.
/// The Oura API returns data in an envelope with optional pagination token.
struct OuraAPIResponse<T: Decodable>: Decodable {
    let data: [T]
    let nextToken: String?

    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

/// Result of a paginated API fetch including the data and pagination state.
struct PaginatedResult<T> {
    let items: [T]
    let nextToken: String?

    var hasMore: Bool {
        nextToken != nil
    }
}

// MARK: - Retry Configuration

/// Configuration for retry behavior on transient failures.
struct RetryConfiguration {
    /// Maximum number of retry attempts.
    let maxRetries: Int

    /// Base delay between retries in seconds.
    let baseDelay: TimeInterval

    /// Maximum delay between retries in seconds.
    let maxDelay: TimeInterval

    /// Default configuration with exponential backoff.
    static let `default` = RetryConfiguration(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 30.0
    )
}

// MARK: - Oura API Service

/// Service for fetching health data from the Oura API.
/// Provides async/await methods for all supported endpoints with proper error handling.
///
/// ## Authentication Support
/// The service supports two authentication modes:
/// 1. **Direct token mode**: Set token via `setAccessToken(_:)` (current PAT approach)
/// 2. **Provider mode**: Use an `AuthenticationProvider` for flexible auth (future OAuth2)
///
/// The provider mode takes precedence when configured, allowing seamless migration
/// from PAT to OAuth2 without changing API call sites.
final class OuraAPIService {
    /// Base URL for the Oura API v2.
    private let baseURL = "https://api.ouraring.com/v2/usercollection"

    /// The personal access token for API authentication (direct mode).
    private var accessToken: String?

    /// Optional authentication provider for flexible auth (provider mode).
    private var authProvider: AuthenticationProvider?

    /// URLSession used for network requests.
    private let session: URLSession

    /// JSON decoder configured for Oura API responses.
    private let decoder: JSONDecoder

    /// Retry configuration for handling transient failures.
    private let retryConfig: RetryConfiguration

    /// Creates a new OuraAPIService instance.
    /// - Parameters:
    ///   - accessToken: Optional personal access token. Can be set later via `setAccessToken(_:)`.
    ///   - authProvider: Optional authentication provider for flexible auth.
    ///   - session: URLSession to use for requests. Defaults to `.shared`.
    ///   - retryConfig: Configuration for retry behavior. Defaults to standard configuration.
    init(
        accessToken: String? = nil,
        authProvider: AuthenticationProvider? = nil,
        session: URLSession = .shared,
        retryConfig: RetryConfiguration = .default
    ) {
        self.accessToken = accessToken
        self.authProvider = authProvider
        self.session = session
        self.decoder = JSONDecoder()
        self.retryConfig = retryConfig
    }

    /// Sets the access token for API authentication (direct mode).
    /// - Parameter token: The personal access token from Oura.
    /// - Note: When using provider mode, this token is ignored in favor of the provider.
    func setAccessToken(_ token: String) {
        self.accessToken = token
    }

    /// Clears the current access token.
    func clearAccessToken() {
        self.accessToken = nil
    }

    /// Sets the authentication provider for flexible auth (provider mode).
    /// - Parameter provider: The authentication provider to use.
    /// - Note: Provider mode takes precedence over direct token mode.
    func setAuthProvider(_ provider: AuthenticationProvider) {
        self.authProvider = provider
    }

    /// Clears the authentication provider.
    func clearAuthProvider() {
        self.authProvider = nil
    }

    /// Checks if an access token is configured (either directly or via provider).
    var hasAccessToken: Bool {
        if authProvider?.isConfigured == true {
            return true
        }
        return accessToken != nil && !(accessToken?.isEmpty ?? true)
    }

    /// Retrieves the current access token from either provider or direct storage.
    /// - Returns: The access token if available.
    /// - Throws: `OuraAPIError.missingAccessToken` if no token is configured.
    private func resolveAccessToken() async throws -> String {
        // Provider mode takes precedence
        if let provider = authProvider {
            let result = await provider.getAccessToken()
            switch result {
            case let .success(token):
                return token
            case .failure:
                throw OuraAPIError.missingAccessToken
            case .needsRefresh:
                // For PAT, this means user needs to generate a new token
                throw OuraAPIError.unauthorized
            }
        }

        // Fall back to direct token mode
        guard let token = accessToken, !token.isEmpty else {
            throw OuraAPIError.missingAccessToken
        }
        return token
    }

    // MARK: - Daily Sleep Endpoint

    /// Fetches daily sleep summaries for a date range.
    /// - Parameters:
    ///   - startDate: Start date in YYYY-MM-DD format.
    ///   - endDate: End date in YYYY-MM-DD format.
    ///   - nextToken: Optional pagination token for fetching additional results.
    /// - Returns: Paginated result containing daily sleep data.
    func fetchDailySleep(
        startDate: String,
        endDate: String,
        nextToken: String? = nil
    ) async throws -> PaginatedResult<DailySleep> {
        var queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate)
        ]
        if let nextToken {
            queryItems.append(URLQueryItem(name: "next_token", value: nextToken))
        }

        let response: OuraAPIResponse<DailySleep> = try await fetchData(
            endpoint: "daily_sleep",
            queryItems: queryItems
        )
        return PaginatedResult(items: response.data, nextToken: response.nextToken)
    }

    /// Fetches all daily sleep summaries for a date range, handling pagination automatically.
    /// - Parameters:
    ///   - startDate: Start date in YYYY-MM-DD format.
    ///   - endDate: End date in YYYY-MM-DD format.
    /// - Returns: Array of all daily sleep data for the range.
    func fetchAllDailySleep(startDate: String, endDate: String) async throws -> [DailySleep] {
        try await fetchAllPages { nextToken in
            try await self.fetchDailySleep(
                startDate: startDate,
                endDate: endDate,
                nextToken: nextToken
            )
        }
    }

    // MARK: - Daily Readiness Endpoint

    /// Fetches daily readiness scores for a date range.
    /// - Parameters:
    ///   - startDate: Start date in YYYY-MM-DD format.
    ///   - endDate: End date in YYYY-MM-DD format.
    ///   - nextToken: Optional pagination token for fetching additional results.
    /// - Returns: Paginated result containing daily readiness data.
    func fetchDailyReadiness(
        startDate: String,
        endDate: String,
        nextToken: String? = nil
    ) async throws -> PaginatedResult<DailyReadiness> {
        var queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate)
        ]
        if let nextToken {
            queryItems.append(URLQueryItem(name: "next_token", value: nextToken))
        }

        let response: OuraAPIResponse<DailyReadiness> = try await fetchData(
            endpoint: "daily_readiness",
            queryItems: queryItems
        )
        return PaginatedResult(items: response.data, nextToken: response.nextToken)
    }

    /// Fetches all daily readiness scores for a date range, handling pagination automatically.
    /// - Parameters:
    ///   - startDate: Start date in YYYY-MM-DD format.
    ///   - endDate: End date in YYYY-MM-DD format.
    /// - Returns: Array of all daily readiness data for the range.
    func fetchAllDailyReadiness(startDate: String, endDate: String) async throws -> [DailyReadiness] {
        try await fetchAllPages { nextToken in
            try await self.fetchDailyReadiness(
                startDate: startDate,
                endDate: endDate,
                nextToken: nextToken
            )
        }
    }

    // MARK: - Sleep (Detailed) Endpoint

    /// Fetches detailed sleep period data for a date range.
    /// - Parameters:
    ///   - startDate: Start date in YYYY-MM-DD format.
    ///   - endDate: End date in YYYY-MM-DD format.
    ///   - nextToken: Optional pagination token for fetching additional results.
    /// - Returns: Paginated result containing detailed sleep period data.
    func fetchSleep(
        startDate: String,
        endDate: String,
        nextToken: String? = nil
    ) async throws -> PaginatedResult<SleepPeriod> {
        var queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate)
        ]
        if let nextToken {
            queryItems.append(URLQueryItem(name: "next_token", value: nextToken))
        }

        let response: OuraAPIResponse<SleepPeriod> = try await fetchData(
            endpoint: "sleep",
            queryItems: queryItems
        )
        return PaginatedResult(items: response.data, nextToken: response.nextToken)
    }

    /// Fetches all detailed sleep periods for a date range, handling pagination automatically.
    /// - Parameters:
    ///   - startDate: Start date in YYYY-MM-DD format.
    ///   - endDate: End date in YYYY-MM-DD format.
    /// - Returns: Array of all sleep period data for the range.
    func fetchAllSleep(startDate: String, endDate: String) async throws -> [SleepPeriod] {
        try await fetchAllPages { nextToken in
            try await self.fetchSleep(
                startDate: startDate,
                endDate: endDate,
                nextToken: nextToken
            )
        }
    }

    // MARK: - Heart Rate Endpoint

    /// Fetches heart rate data for a date range.
    /// - Parameters:
    ///   - startDate: Start date in YYYY-MM-DD format.
    ///   - endDate: End date in YYYY-MM-DD format.
    ///   - nextToken: Optional pagination token for fetching additional results.
    /// - Returns: Paginated result containing heart rate data.
    func fetchHeartRate(
        startDate: String,
        endDate: String,
        nextToken: String? = nil
    ) async throws -> PaginatedResult<HeartRate> {
        var queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate)
        ]
        if let nextToken {
            queryItems.append(URLQueryItem(name: "next_token", value: nextToken))
        }

        let response: OuraAPIResponse<HeartRate> = try await fetchData(
            endpoint: "heartrate",
            queryItems: queryItems
        )
        return PaginatedResult(items: response.data, nextToken: response.nextToken)
    }

    /// Fetches all heart rate data for a date range, handling pagination automatically.
    /// - Parameters:
    ///   - startDate: Start date in YYYY-MM-DD format.
    ///   - endDate: End date in YYYY-MM-DD format.
    /// - Returns: Array of all heart rate data for the range.
    func fetchAllHeartRate(startDate: String, endDate: String) async throws -> [HeartRate] {
        try await fetchAllPages { nextToken in
            try await self.fetchHeartRate(
                startDate: startDate,
                endDate: endDate,
                nextToken: nextToken
            )
        }
    }

    // MARK: - Private Helpers

    /// Generic method to fetch data from any Oura API endpoint.
    /// - Parameters:
    ///   - endpoint: The API endpoint path (e.g., "daily_sleep").
    ///   - queryItems: URL query parameters.
    /// - Returns: Decoded response of the specified type.
    private func fetchData<T: Decodable>(
        endpoint: String,
        queryItems: [URLQueryItem]
    ) async throws -> T {
        // Resolve token from provider or direct storage
        let token = try await resolveAccessToken()

        guard var urlComponents = URLComponents(string: "\(baseURL)/\(endpoint)") else {
            throw OuraAPIError.invalidURL
        }
        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw OuraAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Execute request with retry logic for transient failures
        return try await executeWithRetry(request: request)
    }

    /// Executes an HTTP request with automatic retry for transient failures.
    /// Uses exponential backoff for rate limiting and server errors.
    /// - Parameter request: The URLRequest to execute.
    /// - Returns: Decoded response of the specified type.
    private func executeWithRetry<T: Decodable>(request: URLRequest) async throws -> T {
        var lastError: Error?
        var attempt = 0

        while attempt <= retryConfig.maxRetries {
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw OuraAPIError.networkError("Invalid response type")
                }

                // Check if we should retry based on status code
                if shouldRetry(statusCode: httpResponse.statusCode), attempt < retryConfig.maxRetries {
                    let delay = calculateBackoffDelay(
                        attempt: attempt,
                        response: httpResponse
                    )
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    attempt += 1
                    continue
                }

                try validateHTTPResponse(httpResponse, data: data)

                return try decoder.decode(T.self, from: data)
            } catch let error as OuraAPIError where isRetryableError(error) {
                lastError = error
                if attempt < retryConfig.maxRetries {
                    let delay = calculateBackoffDelay(attempt: attempt, response: nil)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    attempt += 1
                    continue
                }
            } catch let error as DecodingError {
                throw OuraAPIError.decodingError(error.localizedDescription)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Network errors are retryable
                lastError = OuraAPIError.networkError(error.localizedDescription)
                if attempt < retryConfig.maxRetries {
                    let delay = calculateBackoffDelay(attempt: attempt, response: nil)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    attempt += 1
                    continue
                }
            }

            attempt += 1
        }

        throw lastError ?? OuraAPIError.networkError("Request failed after retries")
    }

    /// Determines if a status code should trigger a retry.
    private func shouldRetry(statusCode: Int) -> Bool {
        switch statusCode {
        case 429: // Rate limit
            return true
        case 500..<600: // Server errors
            return true
        default:
            return false
        }
    }

    /// Determines if an error type is retryable.
    private func isRetryableError(_ error: OuraAPIError) -> Bool {
        switch error {
        case .rateLimitExceeded, .serverError, .networkError:
            return true
        default:
            return false
        }
    }

    /// Calculates the backoff delay for a retry attempt.
    /// Uses exponential backoff with optional Retry-After header support.
    private func calculateBackoffDelay(attempt: Int, response: HTTPURLResponse?) -> TimeInterval {
        // Check for Retry-After header (common for rate limiting)
        if let response,
           let retryAfter = response.value(forHTTPHeaderField: "Retry-After"),
           let seconds = Double(retryAfter) {
            return min(seconds, retryConfig.maxDelay)
        }

        // Exponential backoff: baseDelay * 2^attempt with jitter
        let exponentialDelay = retryConfig.baseDelay * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...0.5) * exponentialDelay
        return min(exponentialDelay + jitter, retryConfig.maxDelay)
    }

    /// Validates the HTTP response and throws appropriate errors for failure cases.
    /// - Parameters:
    ///   - response: The HTTP response to validate.
    ///   - data: The response body data for error message extraction.
    private func validateHTTPResponse(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200..<300:
            return // Success
        case 401:
            throw OuraAPIError.unauthorized
        case 404:
            throw OuraAPIError.notFound
        case 429:
            throw OuraAPIError.rateLimitExceeded
        case 500..<600:
            throw OuraAPIError.serverError(statusCode: response.statusCode)
        default:
            let message = String(data: data, encoding: .utf8)
            throw OuraAPIError.httpError(statusCode: response.statusCode, message: message)
        }
    }

    /// Fetches all pages of data for a paginated endpoint.
    /// - Parameter fetcher: A closure that fetches a single page of results.
    /// - Returns: Combined array of all items from all pages.
    private func fetchAllPages<T>(
        fetcher: (String?) async throws -> PaginatedResult<T>
    ) async throws -> [T] {
        var allItems: [T] = []
        var nextToken: String?

        repeat {
            let result = try await fetcher(nextToken)
            allItems.append(contentsOf: result.items)
            nextToken = result.nextToken
        } while nextToken != nil

        return allItems
    }
}

// MARK: - Date Convenience Extensions

extension OuraAPIService {
    /// Fetches daily sleep summaries for a date range using Date objects.
    /// - Parameters:
    ///   - startDate: Start date.
    ///   - endDate: End date.
    /// - Returns: Paginated result containing daily sleep data.
    func fetchDailySleep(
        startDate: Date,
        endDate: Date
    ) async throws -> PaginatedResult<DailySleep> {
        try await fetchDailySleep(
            startDate: Self.formatDate(startDate),
            endDate: Self.formatDate(endDate)
        )
    }

    /// Fetches daily readiness scores for a date range using Date objects.
    /// - Parameters:
    ///   - startDate: Start date.
    ///   - endDate: End date.
    /// - Returns: Paginated result containing daily readiness data.
    func fetchDailyReadiness(
        startDate: Date,
        endDate: Date
    ) async throws -> PaginatedResult<DailyReadiness> {
        try await fetchDailyReadiness(
            startDate: Self.formatDate(startDate),
            endDate: Self.formatDate(endDate)
        )
    }

    /// Fetches detailed sleep period data for a date range using Date objects.
    /// - Parameters:
    ///   - startDate: Start date.
    ///   - endDate: End date.
    /// - Returns: Paginated result containing detailed sleep period data.
    func fetchSleep(
        startDate: Date,
        endDate: Date
    ) async throws -> PaginatedResult<SleepPeriod> {
        try await fetchSleep(
            startDate: Self.formatDate(startDate),
            endDate: Self.formatDate(endDate)
        )
    }

    /// Fetches heart rate data for a date range using Date objects.
    /// - Parameters:
    ///   - startDate: Start date.
    ///   - endDate: End date.
    /// - Returns: Paginated result containing heart rate data.
    func fetchHeartRate(
        startDate: Date,
        endDate: Date
    ) async throws -> PaginatedResult<HeartRate> {
        try await fetchHeartRate(
            startDate: Self.formatDate(startDate),
            endDate: Self.formatDate(endDate)
        )
    }

    /// Formats a Date as a YYYY-MM-DD string for the Oura API.
    /// - Parameter date: The date to format.
    /// - Returns: Formatted date string.
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}
