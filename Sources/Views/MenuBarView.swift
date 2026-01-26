import SwiftUI

/// The mini dashboard popover displayed when the menu bar icon is clicked.
/// Provides a comprehensive view of health metrics including scores, sleep details, and trends.
struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState

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

#Preview {
    MenuBarView()
        .environmentObject(AppState.shared)
}
