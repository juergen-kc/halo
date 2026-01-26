import SwiftUI

/// Main entry point for the Commander menu bar application.
/// This app runs entirely in the menu bar with no dock icon.
@main
struct CommanderApp: App {
    var body: some Scene {
        MenuBarExtra("Commander", systemImage: "command") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }
}
