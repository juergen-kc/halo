import ServiceManagement
import SwiftUI

/// The mini dashboard popover displayed when the menu bar icon is clicked.
/// Provides a comprehensive view of health metrics including scores, sleep details, and trends.
struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState

    /// Controls display of the first launch prompt sheet.
    @State private var showLaunchAtLoginPrompt = false

    /// Oura web dashboard URL
    private let ouraDashboardURL = URL(string: "https://cloud.ouraring.com/")!

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if appState.hasToken {
                        todaysScoresSection
                    }

                    if let sleepPeriod = appState.currentSleepPeriod {
                        SleepStagesView(sleepPeriod: sleepPeriod)
                    }

                    if let sleep = appState.currentSleep {
                        SleepDetailsView(sleep: sleep)
                    }

                    if !appState.readinessHistory.isEmpty || !appState.sleepHistory.isEmpty {
                        TrendsView(
                            readinessAverage: appState.averageReadinessScore,
                            sleepAverage: appState.averageSleepScore,
                            readinessHistory: appState.readinessHistory.compactMap { $0.score },
                            sleepHistory: appState.sleepHistory.compactMap { $0.score }
                        )

                        TrendGraphsView(
                            sleepHistory: appState.sleepHistory,
                            readinessHistory: appState.readinessHistory,
                            hrvHistory: appState.dailyHRVValues,
                            restingHRHistory: appState.dailyRestingHeartRates
                        )
                    }

                    if appState.hasToken && appState.currentReadiness == nil && appState.currentSleep == nil {
                        noDataSection
                    }

                    if !appState.hasToken {
                        setupPromptSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Divider()

            footerSection
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(width: 320, height: 400)
        .onAppear {
            // Show the launch at login prompt on first launch
            if !appState.hasPromptedForLaunchAtLogin {
                showLaunchAtLoginPrompt = true
            }
        }
        .sheet(isPresented: $showLaunchAtLoginPrompt) {
            LaunchAtLoginPromptView(isPresented: $showLaunchAtLoginPrompt)
                .environmentObject(appState)
        }
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Commander")
                    .font(.headline)
                if let lastFetch = appState.lastFetchTime {
                    Text("Updated \(lastFetch.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if appState.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Button {
                    Task {
                        await appState.fetchData()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Refresh data")
            }
        }
    }

    // MARK: - Today's Scores Section

    @ViewBuilder
    private var todaysScoresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Scores")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(spacing: 24) {
                CircularProgressView(
                    score: appState.sleepScore,
                    quality: appState.sleepQuality,
                    label: "Sleep"
                )

                CircularProgressView(
                    score: appState.readinessScore,
                    quality: appState.scoreQuality,
                    label: "Readiness"
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - No Data Section

    @ViewBuilder
    private var noDataSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("No data available")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let error = appState.lastError {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            } else {
                Text("Tap refresh to load your health data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Setup Prompt Section

    @ViewBuilder
    private var setupPromptSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("Setup Required")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("Configure your Oura Personal Access Token to view your health data.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Open Settings") {
                openWindow(id: "settings")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Footer Section

    @ViewBuilder
    private var footerSection: some View {
        HStack(spacing: 12) {
            Button {
                openURL(ouraDashboardURL)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.system(size: 10))
                    Text("Oura Dashboard")
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            Spacer()

            Button {
                openWindow(id: "settings")
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Settings")
            .keyboardShortcut(",", modifiers: .command)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Quit Commander")
            .keyboardShortcut("q")
        }
    }
}

// MARK: - Launch at Login Prompt View

/// First-launch prompt asking the user about launch at login preference.
struct LaunchAtLoginPromptView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "power.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Launch at Login")
                .font(.headline)

            // swiftlint:disable:next line_length
            Text("Commander can start automatically when you log in to your Mac so it's always available in your menu bar.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button("Don't Enable") {
                    setLaunchAtLogin(enabled: false)
                    dismissPrompt()
                }
                .buttonStyle(.bordered)

                Button("Enable") {
                    setLaunchAtLogin(enabled: true)
                    dismissPrompt()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(width: 300)
    }

    /// Sets the launch at login preference using SMAppService.
    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            appState.launchAtLogin = enabled
        } catch {
            // If registration fails, update state to reflect actual status
            let currentStatus = SMAppService.mainApp.status
            appState.launchAtLogin = (currentStatus == .enabled)
        }
    }

    /// Marks the prompt as shown and dismisses it.
    private func dismissPrompt() {
        appState.hasPromptedForLaunchAtLogin = true
        isPresented = false
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AppState.shared)
}

#Preview("Launch at Login Prompt") {
    LaunchAtLoginPromptView(isPresented: .constant(true))
        .environmentObject(AppState.shared)
}
