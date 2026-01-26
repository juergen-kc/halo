import SwiftUI
import ServiceManagement

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
        }
        .frame(width: 450, height: 350)
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

    var body: some View {
        Form {
            Section {
                Toggle("Enable Morning Summary", isOn: $appState.morningSummaryEnabled)

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
                    }
                }

                Text("Receive a daily summary of your readiness, sleep, and activity scores each morning.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Morning Summary")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadDeliveryTime()
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
