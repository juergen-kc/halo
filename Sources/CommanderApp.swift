import SwiftUI
import AppKit

/// Main entry point for the Commander menu bar application.
/// This app runs entirely in the menu bar with no dock icon.
@main
struct CommanderApp: App {
    /// Shared application state managing readiness data.
    @StateObject private var appState = AppState.shared

    /// App delegate for handling notification-triggered activation.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

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

        Window("About Commander", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}

/// App delegate that handles notification-based activation requests.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Observer for notification tap events.
    private var notificationObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Observe notification taps to activate the app
        notificationObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.openDashboardFromNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.activateApp()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Activates the application, bringing it to the foreground.
    /// For a menu bar app, this will trigger the popover to appear when the user clicks the icon.
    private func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
    }
}
