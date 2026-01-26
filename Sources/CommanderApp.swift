import SwiftUI

/// Main entry point for the Commander menu bar application.
/// This app runs entirely in the menu bar with no dock icon.
@main
struct CommanderApp: App {
    /// Shared application state managing readiness data.
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            MenuBarIconView(
                readiness: appState.currentReadiness,
                isLoading: appState.isLoading
            )
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
    }
}
