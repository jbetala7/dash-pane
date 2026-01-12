import Cocoa
import ApplicationServices

class AccessibilityWrapper {

    // MARK: - Window Activation

    /// Activate a specific window by PID and window ID
    /// Window ID format: pid * 1000 + windowIndex (or pid * 1000 - 1 for app-only)
    func activateWindow(pid: pid_t, windowID: CGWindowID) -> Bool {
        // Extract window index from our synthetic window ID
        let windowIndex = Int(windowID) - (Int(pid) * 1000)

        // App-only entry (negative index) - just activate the app
        if windowIndex < 0 {
            return activateAppOnly(pid: pid)
        }

        // Get the application element
        let appElement = AXUIElementCreateApplication(pid)

        // Get all windows for this application
        guard let windows = getWindows(for: appElement), windows.count > windowIndex else {
            return activateAppOnly(pid: pid)
        }

        // Activate the window at the specified index
        let targetWindow = windows[windowIndex]
        return focusWindow(targetWindow, pid: pid)
    }

    /// Focus a specific window element
    func focusWindow(_ windowElement: AXUIElement, pid: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            return false
        }

        // Use reopen to bring back windows that were closed with Cmd+W
        reopenApp(app)

        // Activate the application
        let activated = app.activate(options: [.activateIgnoringOtherApps])

        if !activated {
            return false
        }

        // Raise the window
        let raiseResult = AXUIElementPerformAction(windowElement, kAXRaiseAction as CFString)

        // Also try setting it as the main window
        AXUIElementSetAttributeValue(
            windowElement,
            kAXMainAttribute as CFString,
            kCFBooleanTrue
        )

        // And set focus
        AXUIElementSetAttributeValue(
            windowElement,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )

        return raiseResult == .success || activated
    }

    /// Activate app without specific window
    func activateAppOnly(pid: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            return false
        }

        // Use reopen to bring back windows that were closed with Cmd+W
        reopenApp(app)

        // Use activate - doesn't require App Management permission
        return app.activate(options: [.activateIgnoringOtherApps])
    }

    /// Reopen an app to restore closed windows (like clicking Dock icon)
    private func reopenApp(_ app: NSRunningApplication) {
        guard let appName = app.localizedName else { return }

        let script = """
            tell application "\(appName)"
                reopen
            end tell
            """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    // MARK: - Application Element

    /// Get AXUIElement for application by PID
    func getApplicationElement(pid: pid_t) -> AXUIElement {
        return AXUIElementCreateApplication(pid)
    }

    // MARK: - Window Enumeration

    /// Get all windows for an application
    func getWindows(for appElement: AXUIElement) -> [AXUIElement]? {
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowsRef
        )

        guard result == .success,
              let windows = windowsRef as? [AXUIElement] else {
            return nil
        }

        return windows
    }

    /// Get windows for an application by PID
    func getWindows(pid: pid_t) -> [AXUIElement]? {
        let appElement = getApplicationElement(pid: pid)
        return getWindows(for: appElement)
    }

    // MARK: - Window Attributes

    /// Get window title from AXUIElement
    func getWindowTitle(_ window: AXUIElement) -> String? {
        var titleRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            window,
            kAXTitleAttribute as CFString,
            &titleRef
        )
        return result == .success ? titleRef as? String : nil
    }

    /// Get window position
    func getWindowPosition(_ window: AXUIElement) -> CGPoint? {
        var positionRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            &positionRef
        )

        guard result == .success else { return nil }

        var point = CGPoint.zero
        if AXValueGetValue(positionRef as! AXValue, .cgPoint, &point) {
            return point
        }
        return nil
    }

    /// Get window size
    func getWindowSize(_ window: AXUIElement) -> CGSize? {
        var sizeRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            &sizeRef
        )

        guard result == .success else { return nil }

        var size = CGSize.zero
        if AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) {
            return size
        }
        return nil
    }

    // MARK: - Window Actions

    /// Minimize a window
    func minimizeWindow(_ window: AXUIElement) -> Bool {
        let result = AXUIElementSetAttributeValue(
            window,
            kAXMinimizedAttribute as CFString,
            kCFBooleanTrue
        )
        return result == .success
    }

    /// Close a window
    func closeWindow(_ window: AXUIElement) -> Bool {
        var closeButtonRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            window,
            kAXCloseButtonAttribute as CFString,
            &closeButtonRef
        )

        guard result == .success, let closeButton = closeButtonRef else {
            return false
        }

        return AXUIElementPerformAction(closeButton as! AXUIElement, kAXPressAction as CFString) == .success
    }

    /// Check if window is minimized
    func isWindowMinimized(_ window: AXUIElement) -> Bool {
        var minimizedRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            window,
            kAXMinimizedAttribute as CFString,
            &minimizedRef
        )

        guard result == .success else { return false }
        return (minimizedRef as? Bool) ?? false
    }
}
