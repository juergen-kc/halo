import Foundation
import UserNotifications

/// Service responsible for scheduling and managing morning sleep summary notifications.
/// Uses UserNotificationCenter to deliver time-based notifications with sleep insights.
final class NotificationService: NSObject, ObservableObject, @unchecked Sendable {
    /// Shared instance for app-wide access.
    static let shared = NotificationService()

    /// The notification center for scheduling and managing notifications.
    private let notificationCenter = UNUserNotificationCenter.current()

    /// Identifier for the morning summary notification.
    private static let morningSummaryIdentifier = "com.commander.morning-summary"

    /// UserDefaults key for tracking the last notification date.
    private static let lastNotificationDateKey = "lastMorningSummaryNotificationDate"

    /// Category identifier for notification actions.
    private static let categoryIdentifier = "MORNING_SUMMARY"

    /// Current authorization status.
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        notificationCenter.delegate = self
        setupNotificationCategory()
        Task {
            await refreshAuthorizationStatus()
        }
    }

    // MARK: - Authorization

    /// Requests notification authorization from the user.
    /// - Returns: True if authorization was granted.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            return false
        }
    }

    /// Refreshes the current authorization status.
    func refreshAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Checks if notifications are authorized.
    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    // MARK: - Notification Scheduling

    /// Schedules the morning summary notification at the specified time.
    /// - Parameters:
    ///   - hour: The hour component (0-23) for delivery.
    ///   - minute: The minute component (0-59) for delivery.
    ///   - sleepData: Current sleep data to include in the notification.
    ///   - sleepPeriod: Current sleep period with detailed stage information.
    func scheduleMorningSummary(
        hour: Int,
        minute: Int,
        sleepData: DailySleep?,
        sleepPeriod: SleepPeriod?
    ) async {
        // Cancel any existing scheduled notification
        cancelMorningSummary()

        // Don't schedule if not authorized
        guard isAuthorized else { return }

        // Don't schedule if no sleep data available
        guard sleepData != nil || sleepPeriod != nil else { return }

        // Check if we already sent a notification today
        if hasNotificationBeenSentToday() { return }

        let content = createNotificationContent(sleepData: sleepData, sleepPeriod: sleepPeriod)

        // Create a calendar trigger for the specified time
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: Self.morningSummaryIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            // Silently handle scheduling errors
        }
    }

    /// Cancels any scheduled morning summary notification.
    func cancelMorningSummary() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.morningSummaryIdentifier])
    }

    /// Updates the scheduled notification with new sleep data.
    /// Only updates if the notification is enabled and data has changed.
    func updateNotificationContent(
        enabled: Bool,
        hour: Int,
        minute: Int,
        sleepData: DailySleep?,
        sleepPeriod: SleepPeriod?
    ) async {
        if enabled {
            await scheduleMorningSummary(
                hour: hour,
                minute: minute,
                sleepData: sleepData,
                sleepPeriod: sleepPeriod
            )
        } else {
            cancelMorningSummary()
        }
    }

    // MARK: - Notification Content

    /// Creates the notification content with sleep summary information.
    private func createNotificationContent(
        sleepData: DailySleep?,
        sleepPeriod: SleepPeriod?
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Morning Sleep Summary"
        content.categoryIdentifier = Self.categoryIdentifier

        var bodyParts: [String] = []

        // Sleep Score
        if let score = sleepData?.score {
            let quality = ScoreQuality(score: score)
            bodyParts.append("Sleep Score: \(score) (\(quality.description))")
        }

        // Total Sleep Time
        if let totalSleep = sleepPeriod?.totalSleepDuration {
            let hours = totalSleep / 3_600
            let minutes = (totalSleep % 3_600) / 60
            bodyParts.append("Total Sleep: \(hours)h \(minutes)m")
        }

        // Key Insight
        if let insight = generateKeyInsight(sleepData: sleepData, sleepPeriod: sleepPeriod) {
            bodyParts.append(insight)
        }

        content.body = bodyParts.joined(separator: "\n")
        content.sound = .default

        // Add user info for handling the notification tap
        content.userInfo = ["action": "openDashboard"]

        return content
    }

    /// Generates a key insight based on the sleep data.
    /// Returns a personalized message highlighting the most notable aspect of last night's sleep.
    private func generateKeyInsight(sleepData: DailySleep?, sleepPeriod: SleepPeriod?) -> String? {
        // Check for excellent deep sleep
        if let deepSleep = sleepData?.contributors.deepSleep, deepSleep >= 85 {
            return "Great deep sleep!"
        }

        // Check for excellent REM sleep
        if let remSleep = sleepData?.contributors.remSleep, remSleep >= 85 {
            return "Great REM sleep!"
        }

        // Check for excellent efficiency
        if let efficiency = sleepPeriod?.efficiency, efficiency >= 90 {
            return "Excellent sleep efficiency!"
        }

        // Check for good overall score
        if let score = sleepData?.score, score >= 85 {
            return "Well rested!"
        }

        // Check for low sleep score (needs attention)
        if let score = sleepData?.score, score < 70 {
            return "Consider extra rest today."
        }

        // Check for notable HRV
        if let hrv = sleepPeriod?.averageHrv, hrv >= 50 {
            return "Good recovery (HRV: \(hrv)ms)"
        }

        // Default insight based on total sleep
        if let totalSleep = sleepPeriod?.totalSleepDuration {
            let hours = Double(totalSleep) / 3_600.0
            if hours >= 7.5 {
                return "You got enough sleep!"
            } else if hours < 6 {
                return "Try to get more sleep tonight."
            }
        }

        return nil
    }

    // MARK: - Tracking

    /// Checks if a notification has already been sent today.
    private func hasNotificationBeenSentToday() -> Bool {
        guard let lastDate = UserDefaults.standard.object(forKey: Self.lastNotificationDateKey) as? Date else {
            return false
        }
        return Calendar.current.isDateInToday(lastDate)
    }

    /// Records that a notification was sent today.
    private func recordNotificationSent() {
        UserDefaults.standard.set(Date(), forKey: Self.lastNotificationDateKey)
    }

    /// Resets the notification sent tracking (for testing or new day).
    func resetNotificationTracking() {
        UserDefaults.standard.removeObject(forKey: Self.lastNotificationDateKey)
    }

    // MARK: - Setup

    /// Sets up the notification category with actions.
    private func setupNotificationCategory() {
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        notificationCenter.setNotificationCategories([category])
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    /// Handles notification presentation when the app is in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show the notification even when the app is in the foreground
        completionHandler([.banner, .sound])
    }

    /// Handles the user's response to a notification (e.g., tapping it).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if userInfo["action"] as? String == "openDashboard" {
            // Post a notification that the app can observe to show the popover
            Task { @MainActor in
                NotificationCenter.default.post(name: .openDashboardFromNotification, object: nil)
                // Record that the notification was interacted with
                NotificationService.shared.recordNotificationSent()
            }
        }

        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the user taps the morning summary notification to open the dashboard.
    static let openDashboardFromNotification = Notification.Name("openDashboardFromNotification")
}
