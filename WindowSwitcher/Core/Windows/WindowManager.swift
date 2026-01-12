import Cocoa
import Combine

class WindowManager: ObservableObject {

    // MARK: - Published Properties

    @Published var windows: [WindowInfo] = []
    @Published var onScreenWindows: [WindowInfo] = []

    // MARK: - Private Properties

    private let enumerator = WindowEnumerator()
    private let accessibilityWrapper = AccessibilityWrapper()
    private let activationTracker = AppActivationTracker.shared
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Configuration

    var refreshInterval: TimeInterval = 0.5 // seconds - shorter for better responsiveness

    // MARK: - Lifecycle

    func startMonitoring() {
        // Initial refresh
        refreshWindowsSync()

        // Set up periodic refresh
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: refreshInterval,
            repeats: true
        ) { [weak self] _ in
            self?.refreshWindowsSync()
        }

        // Also observe workspace notifications for immediate updates
        setupWorkspaceNotifications()
    }

    func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        cancellables.removeAll()
    }

    // MARK: - Window Operations

    /// Synchronous refresh - updates windows immediately on main thread
    func refreshWindowsSync() {
        let allWindows = enumerator.getAllWindows()
        let onScreen = enumerator.getOnScreenWindows()

        // Sort by MRU (most recently used) order
        let sortedAll = activationTracker.sortByMRU(allWindows)
        let sortedOnScreen = activationTracker.sortByMRU(onScreen)

        // Update on main thread - if already on main thread, update directly
        if Thread.isMainThread {
            self.windows = sortedAll
            self.onScreenWindows = sortedOnScreen
        } else {
            DispatchQueue.main.sync { [weak self] in
                self?.windows = sortedAll
                self?.onScreenWindows = sortedOnScreen
            }
        }
    }

    /// Async refresh for background updates
    func refreshWindows() {
        refreshWindowsSync()
    }

    func loadThumbnail(for window: WindowInfo) -> NSImage? {
        // Thumbnails require screen recording permission - return app icon instead
        return window.appIcon ?? enumerator.getAppIcon(for: window.ownerPID)
    }

    func loadThumbnails(for windows: [WindowInfo]) -> [CGWindowID: NSImage] {
        // Thumbnails require screen recording permission - return app icons instead
        var thumbnails: [CGWindowID: NSImage] = [:]

        for window in windows {
            if let icon = window.appIcon ?? enumerator.getAppIcon(for: window.ownerPID) {
                thumbnails[window.id] = icon
            }
        }

        return thumbnails
    }

    // MARK: - Window Activation

    func activateWindow(_ window: WindowInfo) -> Bool {
        return accessibilityWrapper.activateWindow(pid: window.ownerPID, windowID: window.id)
    }

    func activateWindow(at index: Int) -> Bool {
        guard index >= 0 && index < windows.count else { return false }
        return activateWindow(windows[index])
    }

    // MARK: - Filtering

    func filterCurrentSpace() -> [WindowInfo] {
        let onScreenIDs = enumerator.getOnScreenWindowIDs()
        return windows.filter { onScreenIDs.contains($0.id) }
    }

    func filterByApp(_ appName: String) -> [WindowInfo] {
        return windows.filter { $0.ownerName.lowercased().contains(appName.lowercased()) }
    }

    func groupByApp() -> [String: [WindowInfo]] {
        return Dictionary(grouping: windows) { $0.ownerName }
    }

    // MARK: - Private Methods

    private func setupWorkspaceNotifications() {
        let workspace = NSWorkspace.shared
        let notificationCenter = workspace.notificationCenter

        // App activation
        notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] _ in
                self?.refreshWindowsSync()
            }
            .store(in: &cancellables)

        // App launch
        notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.refreshWindowsSync()
                }
            }
            .store(in: &cancellables)

        // App terminate
        notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .sink { [weak self] _ in
                self?.refreshWindowsSync()
            }
            .store(in: &cancellables)

        // Space changed
        notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .sink { [weak self] _ in
                self?.refreshWindowsSync()
            }
            .store(in: &cancellables)

        // Window notifications
        notificationCenter.publisher(for: NSWorkspace.didHideApplicationNotification)
            .sink { [weak self] _ in
                self?.refreshWindowsSync()
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: NSWorkspace.didUnhideApplicationNotification)
            .sink { [weak self] _ in
                self?.refreshWindowsSync()
            }
            .store(in: &cancellables)
    }
}
