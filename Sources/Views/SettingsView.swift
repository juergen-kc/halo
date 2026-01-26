import SwiftUI

/// Settings view for configuring the Oura Personal Access Token and display preferences.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appState = AppState.shared

    @State private var token: String = ""
    @State private var isValidating = false
    @State private var validationResult: ValidationResult?
    @State private var hasExistingToken = false

    private let keychainService = KeychainService.shared
    private let apiService = OuraAPIService()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Oura API Settings")
                .font(.headline)

            Divider()

            // Token status
            tokenStatusView

            // Token input
            VStack(alignment: .leading, spacing: 8) {
                Text("Personal Access Token")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                SecureField("Enter your Oura PAT", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isValidating)

                Text("Get your token from [cloud.ouraring.com/personal-access-tokens](https://cloud.ouraring.com/personal-access-tokens)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Validation feedback
            if let result = validationResult {
                validationFeedbackView(result)
            }

            Divider()

            // History Period Setting
            VStack(alignment: .leading, spacing: 8) {
                Text("Trend Graph Period")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("History Period", selection: $appState.historyPeriod) {
                    ForEach(HistoryPeriod.allCases) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: appState.historyPeriod) { _ in
                    appState.onHistoryPeriodChanged()
                }

                Text("Choose how much historical data to display in trend graphs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Refresh Interval Setting
            VStack(alignment: .leading, spacing: 8) {
                Text("Background Refresh")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Refresh Interval", selection: $appState.refreshInterval) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 4) {
                    Text("Automatically refresh health data at the selected interval")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if appState.isLowPowerMode {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 2) {
                            Image(systemName: "leaf.fill")
                                .font(.caption2)
                            Text("Low Power Mode (reduced frequency)")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                    }
                }
            }

            Divider()

            // Actions
            HStack {
                if hasExistingToken {
                    Button("Clear Token", role: .destructive) {
                        clearToken()
                    }
                    .disabled(isValidating)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isValidating)

                Button("Save") {
                    Task {
                        await validateAndSave()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(token.isEmpty || isValidating)
            }
        }
        .padding(20)
        .frame(width: 400)
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
        // Don't load the actual token into the field for security
    }

    private func validateAndSave() async {
        isValidating = true
        validationResult = .validating

        // Set the token on the API service for testing
        apiService.setAccessToken(token)

        do {
            // Make a test API call to validate the token
            // Use today's date for a minimal request
            let today = formatDate(Date())
            _ = try await apiService.fetchDailySleep(startDate: today, endDate: today)

            // Token is valid, save to Keychain
            try keychainService.saveToken(token)
            hasExistingToken = true
            validationResult = .success
            token = "" // Clear the input field

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

// MARK: - Validation Result

private enum ValidationResult {
    case validating
    case success
    case failure(String)
    case cleared
}

#Preview {
    SettingsView()
}
