import SwiftUI

/// The main view displayed when the menu bar icon is clicked.
struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with readiness info
            headerSection

            Divider()

            // Readiness details section
            if let readiness = appState.currentReadiness {
                readinessSection(readiness)
                Divider()
            } else if appState.hasToken {
                noDataSection
                Divider()
            }

            // Actions
            Button("Refresh") {
                Task {
                    await appState.fetchReadinessData()
                }
            }
            .keyboardShortcut("r")
            .disabled(appState.isLoading)

            Button("Settings...") {
                openWindow(id: "settings")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 220)
    }

    // MARK: - View Components

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Text("Commander")
                .font(.headline)

            Spacer()

            if appState.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
    }

    @ViewBuilder
    private func readinessSection(_ readiness: DailyReadiness) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Score display
            HStack(alignment: .firstTextBaseline) {
                Text("Readiness")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text(readiness.scoreDisplay)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(scoreColor(for: readiness.scoreQuality))
            }

            // Quality label
            HStack {
                Circle()
                    .fill(scoreColor(for: readiness.scoreQuality))
                    .frame(width: 8, height: 8)

                Text(readiness.scoreQuality.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(readiness.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var noDataSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No readiness data")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let error = appState.lastError {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            } else {
                Text("Tap refresh to load data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func scoreColor(for quality: ScoreQuality) -> Color {
        switch quality.menuBarColorName {
        case "green": return .green
        case "yellow": return .yellow
        case "red": return .red
        default: return .gray
        }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AppState.shared)
}
