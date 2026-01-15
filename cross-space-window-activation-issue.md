# Cross-Space Window Activation Issue in macOS Window Switcher App

## Problem Summary

We're building a macOS window switcher app (similar to Contexts or Alt-Tab) called DashPane. The app shows all open windows across all Spaces/Desktops and allows users to switch to any window using keyboard shortcuts.

**Current Issue:** When the user presses a shortcut key to activate a window that's on a different Space (desktop), it always activates the wrong window. For example, if Chrome has 2 windows on different spaces, pressing the shortcut for either one always opens the same window (usually the one on the current space).

## What We're Trying to Achieve

1. List ALL windows from all applications across ALL Spaces/Desktops (including fullscreen windows which have their own Space)
2. When user selects a window that's on another Space, bring THAT SPECIFIC window to the current Space and focus it

## Technical Background

### macOS Spaces Architecture
- Each desktop is a "Space"
- Fullscreen windows get their own private Space
- The Accessibility API (AXUIElement) only returns windows on the CURRENT Space
- CGWindowListCopyWindowInfo returns windows from ALL Spaces but with limited info (no window titles for other-space windows)

### Our Approach

1. **Window Enumeration:** Use both CGWindowList and Accessibility API:
   - CGWindowList gives us window IDs for ALL windows across spaces
   - Accessibility API gives us titles and proper filtering for CURRENT space windows
   - We cache window titles when we see them via AX, then use cached titles for windows on other spaces

2. **Window Activation:** When activating a window:
   - First check if window is in current AX list (current space) - activate directly
   - If not in AX list (other space), use `CGSMoveWindowToSpace` to move window to current space, then activate

## Current Code Implementation

### 1. Bridging Header (Private APIs)

```c
// DashPane-Bridging-Header.h

#ifndef DashPane_Bridging_Header_h
#define DashPane_Bridging_Header_h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ApplicationServices/ApplicationServices.h>

// Private API to get CGWindowID from AXUIElement
extern AXError _AXUIElementGetWindow(AXUIElementRef element, CGWindowID *windowID);

// Private Space APIs
typedef uint64_t CGSConnectionID;
typedef uint64_t CGSSpaceID;

// Get the main connection ID
extern CGSConnectionID CGSMainConnectionID(void);

// Copy spaces information
// Mask: 0x1 = Current space, 0x2 = Other spaces, 0x4 = All spaces
extern CFArrayRef CGSCopySpaces(CGSConnectionID cid, int mask);

// Note: CGSMoveWindowToSpace is loaded dynamically in AccessibilityWrapper.swift

#endif
```

### 2. AccessibilityWrapper.swift (Window Activation)

```swift
import Cocoa
import ApplicationServices

// Dynamic function type for CGSMoveWindowToSpace
private typealias CGSMoveWindowToSpaceFunc = @convention(c) (CGSConnectionID, CGWindowID, CGSSpaceID) -> Void

class AccessibilityWrapper {

    // MARK: - Private API Dynamic Loading

    /// Dynamically loaded CGSMoveWindowToSpace function
    private lazy var moveWindowToSpace: CGSMoveWindowToSpaceFunc? = {
        // Load from SkyLight framework
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY) else {
            return nil
        }
        guard let symbol = dlsym(handle, "CGSMoveWindowToSpace") else {
            return nil
        }
        return unsafeBitCast(symbol, to: CGSMoveWindowToSpaceFunc.self)
    }()

    // MARK: - Window Activation

    /// Activate a specific window by PID and window index
    /// windowIndex: -1 for app-only, otherwise the index in the app's window list
    func activateWindow(pid: pid_t, windowIndex: Int) -> Bool {
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

    /// Activate a specific window by PID and window ID
    /// This method finds the window by its CGWindowID, which works even for windows on other spaces
    func activateWindow(pid: pid_t, windowID: CGWindowID) -> Bool {
        // Get the application element
        let appElement = AXUIElementCreateApplication(pid)

        // Get all windows for this application
        if let windows = getWindows(for: appElement) {
            // Find the window with matching ID
            for window in windows {
                var axWindowID: CGWindowID = 0
                if _AXUIElementGetWindow(window, &axWindowID) == .success && axWindowID == windowID {
                    return focusWindow(window, pid: pid)
                }
            }
        }

        // Window not found in current AX list - it's on another space
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            return false
        }

        // Use private API to move window to current space instead of switching spaces
        let cgsConnection = CGSMainConnectionID()
        if let currentSpaceID = getCurrentSpaceID(connection: cgsConnection),
           let moveFunc = moveWindowToSpace {
            moveFunc(cgsConnection, windowID, currentSpaceID)

            // After moving, try to find and focus the window
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                let newAppElement = AXUIElementCreateApplication(pid)
                if let newWindows = self?.getWindows(for: newAppElement) {
                    for window in newWindows {
                        var axWindowID: CGWindowID = 0
                        if _AXUIElementGetWindow(window, &axWindowID) == .success && axWindowID == windowID {
                            _ = self?.focusWindow(window, pid: pid)
                            return
                        }
                    }
                }
            }

            // Also activate the app
            reopenApp(app)
            return app.activate(options: [.activateIgnoringOtherApps])
        }

        // Fallback: just activate the app
        reopenApp(app)
        return app.activate(options: [.activateIgnoringOtherApps])
    }

    /// Get current space ID using private API
    private func getCurrentSpaceID(connection: CGSConnectionID) -> CGSSpaceID? {
        guard let spacesRef = CGSCopySpaces(connection, 1) else { // 1 = current space
            return nil
        }
        let spaces = spacesRef.takeRetainedValue() as NSArray
        guard spaces.count > 0, let spaceID = spaces[0] as? CGSSpaceID else {
            return nil
        }
        return spaceID
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

    /// Get AXUIElement for application by PID
    func getApplicationElement(pid: pid_t) -> AXUIElement {
        return AXUIElementCreateApplication(pid)
    }
}
```

### 3. WindowManager.swift (Calls Activation)

```swift
// MARK: - Window Activation

func activateWindow(_ window: WindowInfo) -> Bool {
    // Use window ID for activation - works across spaces
    return accessibilityWrapper.activateWindow(pid: window.ownerPID, windowID: window.id)
}
```

### 4. WindowEnumerator.swift (Window Enumeration with Title Caching)

```swift
import Cocoa
import CoreGraphics
import ApplicationServices

class WindowEnumerator {

    // MARK: - Caches

    /// Cache of window titles by window ID - persists across space changes
    /// Key: windowID, Value: (title, appName, lastSeen)
    private var windowTitleCache: [CGWindowID: (title: String, appName: String, lastSeen: Date)] = [:]

    /// Cache cleanup interval
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes

    // MARK: - Window Enumeration

    /// Get all windows for running applications
    /// Uses CGWindowList to get windows across all spaces
    func getAllWindows() -> [WindowInfo] {
        var allWindows: [WindowInfo] = []
        var appsWithWindows = Set<pid_t>()
        var seenWindowIDs = Set<CGWindowID>()

        // Build a map of running apps by PID
        let runningApps = NSWorkspace.shared.runningApplications
        var appsByPID: [pid_t: NSRunningApplication] = [:]
        for app in runningApps {
            if app.activationPolicy == .regular {
                appsByPID[app.processIdentifier] = app
            }
        }

        // Clean up expired cache entries
        let now = Date()
        windowTitleCache = windowTitleCache.filter {
            now.timeIntervalSince($0.value.lastSeen) < cacheExpirationInterval
        }

        // Build AX window data cache for titles and activation indices
        var axWindowData: [CGWindowID: (index: Int, title: String, isFullscreen: Bool)] = [:]

        for (pid, app) in appsByPID {
            guard !app.isTerminated else { continue }

            let appName = app.localizedName ?? app.bundleURL?.lastPathComponent ?? "Unknown"
            let appElement = AXUIElementCreateApplication(pid)
            var windowsRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(
                appElement,
                kAXWindowsAttribute as CFString,
                &windowsRef
            )

            guard result == .success, let axWindows = windowsRef as? [AXUIElement] else {
                continue
            }

            for (index, axWindow) in axWindows.enumerated() {
                // Only standard windows
                var subroleRef: CFTypeRef?
                guard AXUIElementCopyAttributeValue(
                    axWindow,
                    kAXSubroleAttribute as CFString,
                    &subroleRef
                ) == .success,
                      let subrole = subroleRef as? String,
                      subrole == "AXStandardWindow" else {
                    continue
                }

                // Get window ID
                var realWindowID: CGWindowID = 0
                guard _AXUIElementGetWindow(axWindow, &realWindowID) == .success
                      && realWindowID != 0 else {
                    continue
                }

                // Get title
                var titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef)
                let title = (titleRef as? String) ?? ""

                // Check if fullscreen
                var fullscreenRef: CFTypeRef?
                AXUIElementCopyAttributeValue(axWindow, "AXFullScreen" as CFString, &fullscreenRef)
                let isFullscreen = (fullscreenRef as? Bool) ?? false

                axWindowData[realWindowID] = (index: index, title: title, isFullscreen: isFullscreen)

                // Cache the window title for when it goes to another space
                windowTitleCache[realWindowID] = (title: title, appName: appName, lastSeen: now)
            }
        }

        // Use CGWindowList to get ALL windows across all spaces
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
              as? [[String: Any]] else {
            return allWindows
        }

        for windowDict in windowList {
            guard let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID,
                  let pid = windowDict[kCGWindowOwnerPID as String] as? pid_t,
                  let layer = windowDict[kCGWindowLayer as String] as? Int else {
                continue
            }

            // Only include normal layer windows (layer 0)
            guard layer == 0 else { continue }

            // Must be from a regular app
            guard let app = appsByPID[pid] else { continue }

            // Skip if we've already seen this window ID
            guard !seenWindowIDs.contains(windowID) else { continue }

            // Get window bounds
            var bounds = CGRect.zero
            if let boundsDict = windowDict[kCGWindowBounds as String] as? [String: Any] {
                bounds = CGRect(
                    x: boundsDict["X"] as? CGFloat ?? 0,
                    y: boundsDict["Y"] as? CGFloat ?? 0,
                    width: boundsDict["Width"] as? CGFloat ?? 800,
                    height: boundsDict["Height"] as? CGFloat ?? 600
                )
            }

            // Skip tiny windows
            if bounds.width < 50 || bounds.height < 50 {
                continue
            }

            let appName = app.localizedName ?? app.bundleURL?.lastPathComponent ?? "Unknown"
            let isOnScreen = windowDict[kCGWindowIsOnscreen as String] as? Bool ?? false
            let cgTitle = windowDict[kCGWindowName as String] as? String ?? ""

            // Get title and index from AX data if available
            let windowTitle: String
            let windowIndex: Int
            let isFullscreen: Bool

            if let axData = axWindowData[windowID] {
                // Window is in AX list (current space) - use AX data
                windowTitle = axData.title
                windowIndex = axData.index
                isFullscreen = axData.isFullscreen
            } else {
                // Window NOT in AX list - it's on another space
                // Check if we have this window in our title cache
                if let cachedData = windowTitleCache[windowID] {
                    // We've seen this window before - use cached title
                    windowTitle = cachedData.title
                    windowIndex = 0  // <-- PROBLEM: We don't have the real index!
                    isFullscreen = false
                } else {
                    // Never seen this window - can't identify it without a title
                    let screens = NSScreen.screens
                    let isScreenSized = screens.contains { screen in
                        let screenFrame = screen.frame
                        return abs(bounds.width - screenFrame.width) < 10 &&
                               abs(bounds.height - screenFrame.height) < 10
                    }

                    guard !cgTitle.isEmpty || isScreenSized else { continue }

                    windowTitle = cgTitle
                    windowIndex = 0
                    isFullscreen = isScreenSized
                }
            }

            seenWindowIDs.insert(windowID)

            var windowInfo = WindowInfo(
                id: windowID,  // <-- This is the CGWindowID
                ownerPID: pid,
                ownerName: appName,
                windowTitle: windowTitle,
                bounds: bounds,
                layer: layer,
                isOnScreen: true,
                spaceID: nil
            )

            windowInfo.appIcon = app.icon
            windowInfo.windowIndex = windowIndex
            windowInfo.isFullscreen = isFullscreen
            windowInfo.isCurrentSpace = isOnScreen

            allWindows.append(windowInfo)
            appsWithWindows.insert(pid)
        }

        return allWindows
    }
}
```

### 5. WindowInfo.swift (Data Model)

```swift
struct WindowInfo: Identifiable, Hashable {
    let id: CGWindowID           // The CGWindowID - unique across all windows
    let ownerPID: pid_t
    let ownerName: String
    let windowTitle: String
    let bounds: CGRect
    let layer: Int
    var isOnScreen: Bool
    var spaceID: Int?

    var appIcon: NSImage?
    var windowIndex: Int = 0     // Index in AX window list (for activation)
    var isFullscreen: Bool = false
    var isAppOnly: Bool = false
    var isCurrentSpace: Bool = true
}
```

## What We've Tried

1. **Using window index for activation** - Failed because AX only returns windows on current space, so index is wrong for other-space windows

2. **Using CGWindowID for activation** - Current approach. We store the CGWindowID and try to match it, but:
   - AX API doesn't return windows on other spaces
   - We can't find the window to activate it directly

3. **CGSMoveWindowToSpace** - Trying to move the window from its current space to the current space:
   - Had linker errors initially (fixed with dlsym)
   - Now loads dynamically but doesn't seem to work
   - The window doesn't appear to move to the current space

4. **CGSGetWindowWorkspace** - Tried to get which space a window is on, but this API crashed the app

## Questions

1. Is `CGSMoveWindowToSpace` the correct API to move a window between spaces? What are its exact parameters?

2. Is there a different approach to activate a window on another space? Perhaps switching TO that space instead of moving the window?

3. Are there other private APIs we should look into like `CGSAddWindowToSpace`, `CGSRemoveWindowFromSpace`, or Mission Control related APIs?

4. How do apps like Contexts, Alt-Tab, or Witch handle this? They can activate any window from any space.

## Environment

- macOS Sequoia 15.x
- Xcode 17
- Swift 5
- App has Accessibility permissions granted

## Desired Behavior

When user presses shortcut for a window on another space:
1. Either move that window to current space and focus it, OR
2. Switch to that space and focus the window

Either approach would work - we just need to be able to activate the SPECIFIC window the user selected, not just any window from that app.
