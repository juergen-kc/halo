import Foundation
import Network

/// Monitors network connectivity state and notifies observers of changes.
/// Uses the Network framework's NWPathMonitor for efficient system-level monitoring.
@MainActor
final class NetworkMonitor: ObservableObject {
    /// Whether the device currently has network connectivity.
    @Published private(set) var isConnected: Bool = true

    /// Whether the current connection is considered expensive (cellular/hotspot).
    @Published private(set) var isExpensive: Bool = false

    /// Whether the current connection is constrained (Low Data Mode).
    @Published private(set) var isConstrained: Bool = false

    /// The type of the current network interface.
    @Published private(set) var connectionType: ConnectionType = .unknown

    /// Shared instance for app-wide network monitoring.
    static let shared = NetworkMonitor()

    /// The underlying network path monitor.
    private var monitor: NWPathMonitor?

    /// Dedicated queue for network monitoring callbacks.
    private let monitorQueue = DispatchQueue(label: "com.commander.networkmonitor")

    /// Connection type enumeration for UI display.
    enum ConnectionType: String, Sendable {
        case wifi = "WiFi"
        case cellular = "Cellular"
        case wiredEthernet = "Ethernet"
        case other = "Other"
        case unknown = "Unknown"
    }

    private init() {
        startMonitoring()
    }

    /// Starts monitoring network connectivity.
    private func startMonitoring() {
        let newMonitor = NWPathMonitor()
        newMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.handlePathUpdate(path)
            }
        }
        newMonitor.start(queue: monitorQueue)
        monitor = newMonitor
    }

    /// Handles network path updates from the monitor.
    private func handlePathUpdate(_ path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained

        // Determine the connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wiredEthernet
        } else if path.usesInterfaceType(.other) {
            connectionType = .other
        } else {
            connectionType = .unknown
        }
    }
}
