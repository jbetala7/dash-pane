import Cocoa
import CoreGraphics
import ApplicationServices

class WindowEnumerator {

    // MARK: - Window Enumeration

    /// Get all windows for running applications
    func getAllWindows() -> [WindowInfo] {
        var allWindows: [WindowInfo] = []
        let runningApps = NSWorkspace.shared.runningApplications
        var appsWithWindows = Set<pid_t>()

        // Enumerate windows for each app
        for app in runningApps {
            guard app.activationPolicy == .regular else { continue }

            let appWindows = getWindowsForApp(app)
            if !appWindows.isEmpty {
                appsWithWindows.insert(app.processIdentifier)
                allWindows.append(contentsOf: appWindows)
            }
        }

        // Add app-only entries for running apps without windows
        for app in runningApps {
            guard app.activationPolicy == .regular else { continue }

            if !appsWithWindows.contains(app.processIdentifier) {
                let appEntry = createAppOnlyEntry(for: app)
                allWindows.append(appEntry)
            }
        }

        return allWindows
    }

    /// Get windows for a specific application
    /// Returns empty array if enumeration fails (defensive against AX crashes)
    private func getWindowsForApp(_ app: NSRunningApplication) -> [WindowInfo] {
        var windows: [WindowInfo] = []

        // Skip terminated apps
        guard !app.isTerminated else { return windows }

        let pid = app.processIdentifier
        let appName = app.localizedName ?? app.bundleURL?.lastPathComponent ?? "Unknown"

        // Cache the icon early to avoid potential race conditions
        let appIcon: NSImage? = app.icon

        let appElement = AXUIElementCreateApplication(pid)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success, let axWindows = windowsRef as? [AXUIElement] else {
            return windows
        }

        for (index, axWindow) in axWindows.enumerated() {
            // Wrap each window processing to prevent crashes from taking down the app
            autoreleasepool {
                if let windowInfo = processWindow(axWindow, index: index, pid: pid, appName: appName, appIcon: appIcon) {
                    windows.append(windowInfo)
                }
            }
        }

        return windows
    }

    /// Process a single window - returns nil if any issue occurs
    private func processWindow(_ axWindow: AXUIElement, index: Int, pid: pid_t, appName: String, appIcon: NSImage?) -> WindowInfo? {
        // Get window subrole - only standard windows
        var subroleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axWindow, kAXSubroleAttribute as CFString, &subroleRef) == .success else {
            return nil
        }
        let subrole = subroleRef as? String
        guard subrole == "AXStandardWindow" else { return nil }

        // Get window title
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef)
        let title = (titleRef as? String) ?? ""

        // Skip position/size queries - they can crash on some macOS versions
        // Use a default reasonable size
        let size = CGSize(width: 800, height: 600)
        let position = CGPoint.zero
        let bounds = CGRect(origin: position, size: size)

        // Check if minimized
        var minimizedRef: CFTypeRef?
        AXUIElementCopyAttributeValue(axWindow, kAXMinimizedAttribute as CFString, &minimizedRef)
        let isMinimized = (minimizedRef as? Bool) ?? false

        // Check if fullscreen
        var fullscreenRef: CFTypeRef?
        AXUIElementCopyAttributeValue(axWindow, "AXFullScreen" as CFString, &fullscreenRef)
        let isFullscreen = (fullscreenRef as? Bool) ?? false

        // Get real window ID using private API
        var realWindowID: CGWindowID = 0
        let axResult = _AXUIElementGetWindow(axWindow, &realWindowID)

        // Use real window ID if available, otherwise create synthetic one
        let windowID: CGWindowID
        if axResult == .success && realWindowID != 0 {
            windowID = realWindowID
        } else {
            windowID = CGWindowID(pid) * 1000 + CGWindowID(index)
        }

        // Don't use private APIs for space detection - they can crash
        let spaceID: Int? = nil

        var windowInfo = WindowInfo(
            id: windowID,
            ownerPID: pid,
            ownerName: appName,
            windowTitle: title,
            bounds: bounds,
            layer: 0,
            isOnScreen: !isMinimized,
            spaceID: spaceID
        )

        windowInfo.isFullscreen = isFullscreen
        windowInfo.appIcon = appIcon

        return windowInfo
    }

    /// Create app-only entry for apps without windows
    private func createAppOnlyEntry(for app: NSRunningApplication) -> WindowInfo {
        let pid = app.processIdentifier
        let appName = app.localizedName ?? app.bundleURL?.lastPathComponent ?? "Unknown"

        // Cache the icon safely
        let appIcon: NSImage? = app.isTerminated ? nil : app.icon

        let windowID = CGWindowID(pid) * 1000 - 1

        var windowInfo = WindowInfo(
            id: windowID,
            ownerPID: pid,
            ownerName: appName,
            windowTitle: "",
            bounds: .zero,
            layer: 0,
            isOnScreen: true,
            spaceID: nil
        )

        windowInfo.isAppOnly = true
        windowInfo.appIcon = appIcon
        return windowInfo
    }

    // MARK: - Space Detection (Disabled - private APIs crash on some systems)

    /// Get the current space ID - returns 0 (disabled)
    func getCurrentSpaceID() -> UInt64 {
        return 0
    }

    /// Get all space IDs - returns empty (disabled)
    func getAllSpaceIDs() -> [UInt64] {
        return []
    }

    /// Get space number - returns 1 (disabled)
    func getSpaceNumber(for spaceID: UInt64) -> Int {
        return 1
    }

    // MARK: - Filtering

    func getOnScreenWindows() -> [WindowInfo] {
        return getAllWindows().filter { $0.isOnScreen }
    }

    func getOnScreenWindowIDs() -> Set<CGWindowID> {
        return Set(getOnScreenWindows().map { $0.id })
    }

    // MARK: - App Icon

    func getAppIcon(for pid: pid_t) -> NSImage? {
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            return nil
        }
        return app.icon
    }
}
