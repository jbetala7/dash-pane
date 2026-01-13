import Cocoa
import Combine

/// Tracks app activations to maintain MRU (Most Recently Used) order
class AppActivationTracker: ObservableObject {

    // MARK: - Singleton

    static let shared = AppActivationTracker()

    // MARK: - Properties

    /// Ordered list of app PIDs, most recently activated first
    @Published private(set) var activationOrder: [pid_t] = []

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupNotifications()
        initializeWithRunningApps()
    }

    // MARK: - Setup

    private func setupNotifications() {
        let workspace = NSWorkspace.shared
        let notificationCenter = workspace.notificationCenter

        // Track app activations
        notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] notification in
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    self?.appActivated(pid: app.processIdentifier)
                }
            }
            .store(in: &cancellables)

        // Remove terminated apps from tracking
        notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .sink { [weak self] notification in
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    self?.appTerminated(pid: app.processIdentifier)
                }
            }
            .store(in: &cancellables)
    }

    /// Initialize with currently running apps, frontmost first
    private func initializeWithRunningApps() {
        let runningApps = NSWorkspace.shared.runningApplications

        // Get the frontmost app first
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            activationOrder.append(frontmost.processIdentifier)
        }

        // Add other running apps (excluding background-only apps)
        for app in runningApps {
            if app.activationPolicy == .regular && !activationOrder.contains(app.processIdentifier) {
                activationOrder.append(app.processIdentifier)
            }
        }
    }

    // MARK: - Tracking

    private func appActivated(pid: pid_t) {
        // Ignore our own app - don't let switcher affect MRU order
        if pid == ProcessInfo.processInfo.processIdentifier {
            return
        }

        // Remove from current position and add to front
        activationOrder.removeAll { $0 == pid }
        activationOrder.insert(pid, at: 0)
    }

    private func appTerminated(pid: pid_t) {
        activationOrder.removeAll { $0 == pid }
    }

    // MARK: - Public API

    /// Get the activation rank for a PID (0 = most recent, higher = older)
    func activationRank(for pid: pid_t) -> Int {
        if let index = activationOrder.firstIndex(of: pid) {
            return index
        }
        // Unknown apps go to the end
        return Int.max
    }

    /// Sort windows by MRU order
    func sortByMRU(_ windows: [WindowInfo]) -> [WindowInfo] {
        return windows.sorted { window1, window2 in
            let rank1 = activationRank(for: window1.ownerPID)
            let rank2 = activationRank(for: window2.ownerPID)
            return rank1 < rank2
        }
    }
}
