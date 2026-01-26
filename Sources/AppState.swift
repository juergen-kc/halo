import Foundation
import SwiftUI

/// Represents the selectable historical data periods for trend graphs.
enum HistoryPeriod: Int, CaseIterable, Identifiable {
    case sevenDays = 7
    case fourteenDays = 14
    case thirtyDays = 30

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .sevenDays: return "7 Days"
        case .fourteenDays: return "14 Days"
        case .thirtyDays: return "30 Days"
        }
    }
}

/// Centralized application state that manages health data and coordinates data fetching.
/// This observable object is shared across the app to ensure consistent state.
@MainActor
final class AppState: ObservableObject {
    /// The most recent daily readiness data.
    @Published private(set) var currentReadiness: DailyReadiness?

    /// The most recent daily sleep data.
    @Published private(set) var currentSleep: DailySleep?

    /// Historical readiness data for trends (configurable period).
    @Published private(set) var readinessHistory: [DailyReadiness] = []

    /// Historical sleep data for trends (configurable period).
    @Published private(set) var sleepHistory: [DailySleep] = []

    /// Historical sleep periods with HRV data for trends (configurable period).
    @Published private(set) var sleepPeriodHistory: [SleepPeriod] = []

    /// Historical heart rate data for resting HR trends (configurable period).
    @Published private(set) var heartRateHistory: [HeartRate] = []

    /// The selected history period for trend graphs. Persisted to UserDefaults.
    @AppStorage("historyPeriodDays") var historyPeriodDays: Int = HistoryPeriod.sevenDays.rawValue

    /// The current history period as an enum value.
    var historyPeriod: HistoryPeriod {
        get { HistoryPeriod(rawValue: historyPeriodDays) ?? .sevenDays }
        set { historyPeriodDays = newValue.rawValue }
    }

    /// The most recent detailed sleep period data with stage durations.
    @Published private(set) var currentSleepPeriod: SleepPeriod?

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

    /// Fetches the latest readiness and sleep data from the Oura API.
    func fetchData() async {
        guard !isLoading else { return }

        isLoading = true
        lastError = nil

        do {
            let token = try keychainService.retrieveToken()
            apiService.setAccessToken(token)
            try await performDataFetch()
        } catch let error as KeychainError where error == .itemNotFound {
            // No token configured - this is expected on first launch
            resetDataOnNoToken()
        } catch {
            self.lastError = error
        }

        isLoading = false
    }

    /// Performs the actual data fetch from the Oura API.
    private func performDataFetch() async throws {
        let today = Date()
        let periodStart = Calendar.current.date(byAdding: .day, value: -historyPeriod.rawValue, to: today) ?? today
        let startDateStr = Self.formatDate(periodStart)
        let endDateStr = Self.formatDate(today)

        // Fetch today's data and historical data concurrently
        async let todayReadiness = apiService.fetchDailyReadiness(startDate: today, endDate: today)
        async let todaySleep = apiService.fetchDailySleep(startDate: today, endDate: today)
        async let todaySleepPeriods = apiService.fetchSleep(startDate: today, endDate: today)
        async let historyReadiness = apiService.fetchAllDailyReadiness(startDate: startDateStr, endDate: endDateStr)
        async let historySleep = apiService.fetchAllDailySleep(startDate: startDateStr, endDate: endDateStr)
        async let historySleepPeriods = apiService.fetchAllSleep(startDate: startDateStr, endDate: endDateStr)
        async let historyHeartRate = apiService.fetchAllHeartRate(startDate: startDateStr, endDate: endDateStr)

        // Await all results
        let readinessResult = try await todayReadiness
        let sleepResult = try await todaySleep
        let sleepPeriodsResult = try await todaySleepPeriods
        let readinessHistoryResult = try await historyReadiness
        let sleepHistoryResult = try await historySleep
        let sleepPeriodHistoryResult = try await historySleepPeriods
        let heartRateHistoryResult = try await historyHeartRate

        // Update state
        self.currentReadiness = readinessResult.items.last
        self.currentSleep = sleepResult.items.last
        self.currentSleepPeriod = sleepPeriodsResult.items.first { $0.type == .longSleep }
            ?? sleepPeriodsResult.items.last
        self.readinessHistory = readinessHistoryResult.sorted { $0.day < $1.day }
        self.sleepHistory = sleepHistoryResult.sorted { $0.day < $1.day }
        self.sleepPeriodHistory = sleepPeriodHistoryResult.filter { $0.type == .longSleep }.sorted { $0.day < $1.day }
        self.heartRateHistory = heartRateHistoryResult.sorted { $0.day < $1.day }
        self.lastFetchTime = Date()
    }

    /// Resets data state when no token is configured.
    private func resetDataOnNoToken() {
        self.lastError = nil
        self.currentReadiness = nil
        self.currentSleep = nil
        self.currentSleepPeriod = nil
        self.readinessHistory = []
        self.sleepHistory = []
        self.sleepPeriodHistory = []
        self.heartRateHistory = []
    }

    /// Fetches the latest readiness data from the Oura API.
    /// Legacy method for backward compatibility.
    func fetchReadinessData() async {
        await fetchData()
    }

    /// Starts automatic periodic data refresh.
    func startAutoRefresh() {
        stopAutoRefresh()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchData()
            }
        }
    }

    /// Stops automatic periodic data refresh.
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    /// Clears all current data and error state.
    func clearData() {
        currentReadiness = nil
        currentSleep = nil
        currentSleepPeriod = nil
        readinessHistory = []
        sleepHistory = []
        sleepPeriodHistory = []
        heartRateHistory = []
        lastError = nil
        lastFetchTime = nil
    }

    /// Called when the API token is updated in settings.
    func onTokenUpdated() {
        Task {
            await fetchData()
        }
    }

    /// Called when the history period is changed in settings.
    /// Triggers a data refresh to fetch the new range.
    func onHistoryPeriodChanged() {
        Task {
            await fetchData()
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

    /// The current sleep score, if available.
    var sleepScore: Int? {
        currentSleep?.score
    }

    /// The quality level of the current sleep score.
    var sleepQuality: ScoreQuality {
        guard let score = sleepScore else { return .unknown }
        return ScoreQuality(score: score)
    }

    /// Average readiness score over the selected history period.
    var averageReadinessScore: Int? {
        let scores = readinessHistory.compactMap { $0.score }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / scores.count
    }

    /// Average sleep score over the selected history period.
    var averageSleepScore: Int? {
        let scores = sleepHistory.compactMap { $0.score }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / scores.count
    }

    /// Average HRV over the selected history period (from sleep periods).
    var averageHRV: Int? {
        let hrvValues = sleepPeriodHistory.compactMap { $0.averageHrv }
        guard !hrvValues.isEmpty else { return nil }
        return hrvValues.reduce(0, +) / hrvValues.count
    }

    /// Average resting heart rate over the selected history period.
    var averageRestingHeartRate: Int? {
        let dailyResting = dailyRestingHeartRates
        guard !dailyResting.isEmpty else { return nil }
        let total = dailyResting.reduce(0) { $0 + $1.value }
        return total / dailyResting.count
    }

    /// Daily resting heart rate values grouped by day.
    /// Returns the minimum resting HR for each day as a (day, value) tuple.
    var dailyRestingHeartRates: [(day: String, value: Int)] {
        // Filter to resting heart rate readings
        let restingReadings = heartRateHistory.filter { $0.source == .rest }

        // Group by day and find the minimum (lowest resting HR is most meaningful)
        var dailyMin: [String: Int] = [:]
        for reading in restingReadings {
            if let existing = dailyMin[reading.day] {
                dailyMin[reading.day] = min(existing, reading.bpm)
            } else {
                dailyMin[reading.day] = reading.bpm
            }
        }

        return dailyMin.sorted { $0.key < $1.key }.map { (day: $0.key, value: $0.value) }
    }

    /// Daily HRV values from sleep periods (one per day).
    var dailyHRVValues: [(day: String, value: Int)] {
        sleepPeriodHistory.compactMap { period in
            guard let hrv = period.averageHrv else { return nil }
            return (day: period.day, value: hrv)
        }
    }

    // MARK: - Private Helpers

    /// Loads the token from Keychain and initiates initial data fetch.
    private func loadTokenAndFetchData() {
        Task {
            await fetchData()
            startAutoRefresh()
        }
    }

    /// Formats a Date as a YYYY-MM-DD string.
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}
