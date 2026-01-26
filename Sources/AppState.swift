import Foundation
import SwiftUI

/// Centralized application state that manages readiness data and coordinates data fetching.
/// This observable object is shared across the app to ensure consistent state.
@MainActor
final class AppState: ObservableObject {
    /// The most recent daily readiness data.
    @Published private(set) var currentReadiness: DailyReadiness?

    /// Whether data is currently being fetched.
    @Published private(set) var isLoading = false

    /// The most recent error that occurred during data fetching.
    @Published private(set) var lastError: Error?

    /// Timestamp of the last successful data fetch.
    @Published private(set) var lastFetchTime: Date?

    /// Service for fetching data from the Oura API.
    private let apiService: OuraAPIService

    /// Service for managing the API token in Keychain.
    private let keychainService: KeychainService

    /// Timer for automatic data refresh.
    private var refreshTimer: Timer?

    /// Refresh interval in seconds (default: 15 minutes).
    private let refreshInterval: TimeInterval = 15 * 60

    /// Shared instance for app-wide access.
    static let shared = AppState()

    init(
        apiService: OuraAPIService = OuraAPIService(),
        keychainService: KeychainService = .shared
    ) {
        self.apiService = apiService
        self.keychainService = keychainService
        loadTokenAndFetchData()
    }

    // MARK: - Public Interface

    /// Fetches the latest readiness data from the Oura API.
    func fetchReadinessData() async {
        guard !isLoading else { return }

        isLoading = true
        lastError = nil

        do {
            // Ensure we have a valid token
            let token = try keychainService.retrieveToken()
            apiService.setAccessToken(token)

            // Fetch today's readiness data
            let today = Date()
            let result = try await apiService.fetchDailyReadiness(
                startDate: today,
                endDate: today
            )

            // Use the most recent readiness entry
            self.currentReadiness = result.items.last
            self.lastFetchTime = Date()
        } catch let error as KeychainError where error == .itemNotFound {
            // No token configured - this is expected on first launch
            self.lastError = nil
            self.currentReadiness = nil
        } catch {
            self.lastError = error
        }

        isLoading = false
    }

    /// Starts automatic periodic data refresh.
    func startAutoRefresh() {
        stopAutoRefresh()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchReadinessData()
            }
        }
    }

    /// Stops automatic periodic data refresh.
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    /// Clears the current readiness data and error state.
    func clearData() {
        currentReadiness = nil
        lastError = nil
        lastFetchTime = nil
    }

    /// Called when the API token is updated in settings.
    func onTokenUpdated() {
        Task {
            await fetchReadinessData()
        }
    }

    // MARK: - Computed Properties for UI

    /// The current readiness score, if available.
    var readinessScore: Int? {
        currentReadiness?.score
    }

    /// The quality level of the current readiness score.
    var scoreQuality: ScoreQuality {
        guard let score = readinessScore else { return .unknown }
        return ScoreQuality(score: score)
    }

    /// Whether the app has a configured API token.
    var hasToken: Bool {
        keychainService.hasToken()
    }

    // MARK: - Private Helpers

    /// Loads the token from Keychain and initiates initial data fetch.
    private func loadTokenAndFetchData() {
        Task {
            await fetchReadinessData()
            startAutoRefresh()
        }
    }
}
