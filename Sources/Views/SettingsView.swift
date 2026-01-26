import SwiftUI
import ServiceManagement
import UserNotifications

/// Settings view with tabbed interface for configuring app preferences.
/// Accessible via menu bar dropdown or Cmd+, keyboard shortcut.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            AccountSettingsTab()
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }

            DisplaySettingsTab()
                .tabItem {
                    Label("Display", systemImage: "display")
                }

            NotificationsSettingsTab()
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }

            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            OAuth2SetupTab()
                .tabItem {
                    Label("OAuth2", systemImage: "lock.shield")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - Account Settings Tab

/// Account tab for PAT configuration.
struct AccountSettingsTab: View {
    @EnvironmentObject private var appState: AppState

    @State private var token: String = ""
    @State private var isValidating = false
    @State private var validationResult: ValidationResult?
    @State private var hasExistingToken = false

    private let keychainService = KeychainService.shared
    private let apiService = OuraAPIService()

    var body: some View {
        Form {
            Section {
                tokenStatusView
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("Enter your Oura PAT", text: $token)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isValidating)

                    Text("Get your token from [cloud.ouraring.com/personal-access-tokens](https://cloud.ouraring.com/personal-access-tokens)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Personal Access Token")
            }

            if let result = validationResult {
                Section {
                    validationFeedbackView(result)
                }
            }

            Section {
                HStack {
                    if hasExistingToken {
                        Button("Clear Token", role: .destructive) {
                            clearToken()
                        }
                        .disabled(isValidating)
                    }

                    Spacer()

                    Button("Save Token") {
                        Task {
                            await validateAndSave()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(token.isEmpty || isValidating)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadExistingToken()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var tokenStatusView: some View {
        HStack(spacing: 8) {
            Image(systemName: hasExistingToken ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(hasExistingToken ? .green : .secondary)

            Text(hasExistingToken ? "Token configured" : "No token configured")
                .foregroundColor(hasExistingToken ? .primary : .secondary)
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private func validationFeedbackView(_ result: ValidationResult) -> some View {
        HStack(spacing: 8) {
            switch result {
            case .validating:
                ProgressView()
                    .scaleEffect(0.8)
                Text("Validating token...")
                    .foregroundColor(.secondary)

            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Token validated and saved successfully")
                    .foregroundColor(.green)

            case let .failure(message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text(message)
                    .foregroundColor(.red)

            case .cleared:
                Image(systemName: "trash.fill")
                    .foregroundColor(.orange)
                Text("Token cleared")
                    .foregroundColor(.orange)
            }
        }
        .font(.subheadline)
    }

    // MARK: - Actions

    private func loadExistingToken() {
        hasExistingToken = keychainService.hasToken()
    }

    private func validateAndSave() async {
        isValidating = true
        validationResult = .validating

        apiService.setAccessToken(token)

        do {
            let today = formatDate(Date())
            _ = try await apiService.fetchDailySleep(startDate: today, endDate: today)

            try keychainService.saveToken(token)
            hasExistingToken = true
            validationResult = .success
            token = ""

            appState.onTokenUpdated()
        } catch let error as OuraAPIError {
            validationResult = .failure(error.localizedDescription)
        } catch let error as KeychainError {
            validationResult = .failure(error.localizedDescription)
        } catch {
            validationResult = .failure("Unexpected error: \(error.localizedDescription)")
        }

        isValidating = false
    }

    private func clearToken() {
        do {
            try keychainService.deleteToken()
            hasExistingToken = false
            validationResult = .cleared
            token = ""
        } catch {
            validationResult = .failure("Failed to clear token: \(error.localizedDescription)")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}

// MARK: - Display Settings Tab

/// Display tab for configuring visual preferences like history period.
struct DisplaySettingsTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section {
                Picker("Period", selection: $appState.historyPeriod) {
                    ForEach(HistoryPeriod.allCases) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: appState.historyPeriod) { _ in
                    appState.onHistoryPeriodChanged()
                }

                Text("Choose how much historical data to display in trend graphs.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Trend Graph Period")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Notifications Settings Tab

/// Notifications tab for configuring morning summary and alert preferences.
struct NotificationsSettingsTab: View {
    @EnvironmentObject private var appState: AppState

    @State private var deliveryTime = Date()
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            Section {
                Toggle("Enable Morning Summary", isOn: $appState.morningSummaryEnabled)
                    .onChange(of: appState.morningSummaryEnabled) { newValue in
                        if newValue {
                            requestNotificationPermission()
                        }
                        appState.onMorningSummarySettingsChanged()
                    }

                if appState.morningSummaryEnabled {
                    DatePicker(
                        "Delivery Time",
                        selection: $deliveryTime,
                        displayedComponents: .hourAndMinute
                    )
                    .onChange(of: deliveryTime) { newValue in
                        let calendar = Calendar.current
                        appState.morningSummaryHour = calendar.component(.hour, from: newValue)
                        appState.morningSummaryMinute = calendar.component(.minute, from: newValue)
                        appState.onMorningSummarySettingsChanged()
                    }

                    // Show permission status warning if denied
                    if authorizationStatus == .denied {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text("Notifications are disabled in System Settings")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                    }
                }

                Text("Receive a daily summary of your sleep score and insights each morning.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Morning Summary")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadDeliveryTime()
            checkAuthorizationStatus()
        }
    }

    private func loadDeliveryTime() {
        var components = DateComponents()
        components.hour = appState.morningSummaryHour
        components.minute = appState.morningSummaryMinute
        if let date = Calendar.current.date(from: components) {
            deliveryTime = date
        }
    }

    private func requestNotificationPermission() {
        Task {
            _ = await appState.requestNotificationAuthorization()
            checkAuthorizationStatus()
        }
    }

    private func checkAuthorizationStatus() {
        authorizationStatus = appState.notificationAuthorizationStatus
    }
}

// MARK: - General Settings Tab

/// General tab for configuring refresh interval and launch behavior.
struct GeneralSettingsTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section {
                Picker("Interval", selection: $appState.refreshInterval) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 4) {
                    Text("Automatically refresh health data at the selected interval.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if appState.isLowPowerMode {
                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.caption2)
                        Text("Low Power Mode active — refresh frequency is reduced")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                }
            } header: {
                Text("Background Refresh")
            }

            Section {
                Toggle("Launch at Login", isOn: $appState.launchAtLogin)
                    .onChange(of: appState.launchAtLogin) { newValue in
                        setLaunchAtLogin(enabled: newValue)
                    }

                Text("Automatically start Commander when you log in to your Mac.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Startup")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            syncLaunchAtLoginState()
        }
    }

    /// Sets or removes the app from Login Items using ServiceManagement.
    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Revert the toggle on failure
            appState.launchAtLogin = !enabled
        }
    }

    /// Syncs the toggle state with the actual system setting.
    private func syncLaunchAtLoginState() {
        let currentStatus = SMAppService.mainApp.status
        appState.launchAtLogin = (currentStatus == .enabled)
    }
}

// MARK: - OAuth2 Setup Tab

/// OAuth2 setup tab providing guidance for developers who want to create their own Oura application.
/// This enables users to use OAuth2 authentication instead of Personal Access Tokens.
struct OAuth2SetupTab: View {
    /// URL for Oura developer portal where users register applications.
    private let developerPortalURL = "https://cloud.ouraring.com/oauth/applications"

    /// URL for Oura API documentation.
    private let apiDocsURL = "https://cloud.ouraring.com/docs"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header section
                headerSection

                Divider()

                // Why OAuth2 section
                whyOAuth2Section

                Divider()

                // Setup steps section
                setupStepsSection

                Divider()

                // Technical details section
                technicalDetailsSection

                Divider()

                // Current status section
                currentStatusSection
            }
            .padding()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("OAuth2 Authentication Setup")
                    .font(.headline)
            }

            // swiftlint:disable:next line_length
            Text("Advanced configuration for developers who want to distribute their own version of this app or use OAuth2 instead of Personal Access Tokens.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var whyOAuth2Section: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Why Use OAuth2?")
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 4) {
                bulletPoint("More secure than sharing Personal Access Tokens")
                bulletPoint("Required for distributing apps to other users")
                bulletPoint("Supports automatic token refresh")
                bulletPoint("Standard authentication flow for third-party apps")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var setupStepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Setup Steps")
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 10) {
                setupStep(
                    number: 1,
                    title: "Register Your Application",
                    description: "Visit the Oura Developer Portal to create a new application."
                )

                Link(destination: URL(string: developerPortalURL)!) {
                    HStack {
                        Image(systemName: "arrow.up.right.square")
                        Text("Open Oura Developer Portal")
                    }
                    .font(.caption)
                }
                .padding(.leading, 24)

                setupStep(
                    number: 2,
                    title: "Configure Application Details",
                    description: "Enter your app name, description, and organization details."
                )

                setupStep(
                    number: 3,
                    title: "Set Redirect URI",
                    description: "Use a custom URL scheme for macOS apps:"
                )

                Text("commander://oauth/callback")
                    .font(.system(.caption, design: .monospaced))
                    .padding(6)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
                    .padding(.leading, 24)

                setupStep(
                    number: 4,
                    title: "Select Scopes",
                    description: "Request the following OAuth2 scopes:"
                )

                VStack(alignment: .leading, spacing: 2) {
                    scopeItem("daily", "Daily summaries (sleep, readiness)")
                    scopeItem("heartrate", "Heart rate data")
                    scopeItem("personal", "Basic profile information")
                }
                .padding(.leading, 24)

                setupStep(
                    number: 5,
                    title: "Save Your Credentials",
                    description: "Copy your Client ID and Client Secret. Keep the secret secure!"
                )
            }
        }
    }

    @ViewBuilder
    private var technicalDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Technical Details")
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 4) {
                technicalDetail("Authorization URL", "https://cloud.ouraring.com/oauth/authorize")
                technicalDetail("Token URL", "https://cloud.ouraring.com/oauth/token")
                technicalDetail("Redirect URI", "commander://oauth/callback")
                technicalDetail("Grant Type", "authorization_code")
            }

            Link(destination: URL(string: apiDocsURL)!) {
                HStack {
                    Image(systemName: "book")
                    Text("View Full API Documentation")
                }
                .font(.caption)
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var currentStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Authentication")
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .foregroundColor(.orange)
                Text("Using Personal Access Token (PAT)")
                    .font(.caption)
            }

            // swiftlint:disable:next line_length
            Text("This app currently uses PAT authentication. OAuth2 support is planned for a future release. The architecture is designed to support both methods.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
            Text(text)
        }
    }

    @ViewBuilder
    private func setupStep(number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Color.blue)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func scopeItem(_ scope: String, _ description: String) -> some View {
        HStack(spacing: 4) {
            Text(scope)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.blue)
            Text("—")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func technicalDetail(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Validation Result

private enum ValidationResult {
    case validating
    case success
    case failure(String)
    case cleared
}

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
}
