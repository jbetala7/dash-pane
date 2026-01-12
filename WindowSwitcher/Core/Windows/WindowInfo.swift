import Cocoa
import ApplicationServices

struct WindowInfo: Identifiable, Hashable {

    // MARK: - Properties

    let id: CGWindowID
    let ownerPID: pid_t
    let ownerName: String
    let windowTitle: String
    let bounds: CGRect
    let layer: Int
    let isOnScreen: Bool
    let spaceID: Int?
    var isFullscreen: Bool = false
    var isAppOnly: Bool = false  // True if this is an app entry without a specific window

    var thumbnail: NSImage?
    var appIcon: NSImage?

    // MARK: - Direct Initializer (for Accessibility API)

    init(id: CGWindowID, ownerPID: pid_t, ownerName: String, windowTitle: String,
         bounds: CGRect, layer: Int, isOnScreen: Bool, spaceID: Int?) {
        self.id = id
        self.ownerPID = ownerPID
        self.ownerName = ownerName
        self.windowTitle = windowTitle
        self.bounds = bounds
        self.layer = layer
        self.isOnScreen = isOnScreen
        self.spaceID = spaceID
        self.thumbnail = nil
        self.appIcon = nil
    }

    // MARK: - Computed Properties

    var displayName: String {
        if windowTitle.isEmpty {
            return ownerName
        }
        return windowTitle
    }

    var fullDisplayName: String {
        if windowTitle.isEmpty {
            return ownerName
        }
        return "\(ownerName) - \(windowTitle)"
    }

    /// First letter of app name for shortcut key
    var shortcutLetter: String {
        let firstChar = ownerName.first ?? Character("?")
        return String(firstChar).lowercased()
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Initializer from Dictionary

extension WindowInfo {

    /// List of system processes/apps to exclude
    private static let excludedApps: Set<String> = [
        "Window Server",
        "Dock",
        "SystemUIServer",
        "Control Center",
        "Notification Center",
        "Spotlight",
        "WindowManager",
        "CursorUIViewService",
        "Open and Save Panel Service",
        "AutoFill",
        "universalAccessAuthWarn",
        "AXVisualSupportAgent",
        "CoreServicesUIAgent",
        "TextInputMenuAgent",
        "TextInputSwitcher",
        "WiFiAgent",
        "SystemUIServer",
        "loginwindow",
        "talagent",
        "ScreenCaptureAgent",
        "imklaunchagent",
        "UAService",
        "Siri",
        "AssistiveControl",
        "Accessibility Inspector",
        "storeuid",
        "com.apple.preference.security.remoteservice",
        "UserNotificationCenter",
        "universalaccessd",
        "coreservicesd"
    ]

    /// Check if this is a valid user-facing window
    private static func isValidWindow(ownerName: String, bounds: CGRect, layer: Int) -> Bool {
        // Must be layer 0 (normal windows)
        guard layer == 0 else { return false }

        // Must have reasonable size
        guard bounds.width > 50 && bounds.height > 50 else { return false }

        // Skip excluded system apps
        guard !excludedApps.contains(ownerName) else { return false }

        // Skip apps ending with "Agent", "Service", "Helper" (likely background processes)
        let lowercaseName = ownerName.lowercased()
        if lowercaseName.hasSuffix("agent") ||
           lowercaseName.hasSuffix("service") ||
           lowercaseName.hasSuffix("helper") ||
           lowercaseName.hasSuffix("daemon") ||
           lowercaseName.contains("uiviewservice") {
            return false
        }

        return true
    }

    init?(from windowDict: [String: Any]) {
        guard let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID,
              let ownerPID = windowDict[kCGWindowOwnerPID as String] as? pid_t,
              let ownerName = windowDict[kCGWindowOwnerName as String] as? String,
              let layer = windowDict[kCGWindowLayer as String] as? Int,
              let boundsDict = windowDict[kCGWindowBounds as String] as? [String: CGFloat]
        else {
            return nil
        }

        let bounds = CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )

        // Validate this is a user-facing window
        guard WindowInfo.isValidWindow(ownerName: ownerName, bounds: bounds, layer: layer) else {
            return nil
        }

        let title = windowDict[kCGWindowName as String] as? String ?? ""
        let isOnScreen = windowDict[kCGWindowIsOnscreen as String] as? Bool ?? false

        self.id = windowID
        self.ownerPID = ownerPID
        self.ownerName = ownerName
        self.windowTitle = title
        self.bounds = bounds
        self.layer = layer
        self.isOnScreen = isOnScreen
        self.spaceID = nil
        self.thumbnail = nil
        self.appIcon = nil
    }
}
