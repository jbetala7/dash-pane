# DashPane - Current Implementation (Still Not Working)

## Problem

Cross-space window activation is not working. When selecting a window that's on another Space/Desktop, the app does NOT switch to that space and activate the correct window.

## What We're Trying to Do

Based on the ChatGPT guide, we implemented:
1. Enumerate windows across all Spaces using CGWindowList
2. When user selects a window on another Space:
   - Get the window's Space ID using `CGSGetWindowWorkspace`
   - Switch to that Space using `CGSSetWorkspace`
   - Wait 80ms for AX to refresh
   - Activate the window via Accessibility API

## Current Symptoms

When pressing a shortcut key for a window on another space:
- The space does NOT switch
- The same window (on current space) gets activated
- OR the app just activates without focusing the correct window

## All Relevant Code

### 1. Bridging Header (DashPane-Bridging-Header.h)

```c
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
// Mask values: 0x1 = Current space, 0x2 = Other spaces, 0x4 = All spaces
extern CFArrayRef CGSCopySpaces(CGSConnectionID cid, int mask);

// Note: The following private APIs are loaded dynamically in SpaceManager.swift
// to avoid linker issues:
// - CGSGetWindowWorkspace(conn, windowID, &spaceID) -> Int32 (0=success)
// - CGSGetActiveSpace(conn) -> CGSSpaceID
// - CGSSetWorkspace(conn, spaceID) -> void

#endif
```

### 2. SpaceManager.swift (Loads Private APIs Dynamically)

```swift
import Cocoa
import CoreGraphics

class SpaceManager: ObservableObject {

    // MARK: - Singleton
    static let shared = SpaceManager()

    // MARK: - Published Properties
    @Published var currentSpaceID: Int?
    @Published var allSpaces: [Int] = []

    // MARK: - Properties
    private let windowEnumerator = WindowEnumerator()

    // MARK: - Private API Function Types
    private typealias CGSGetWindowWorkspaceFunc = @convention(c) (CGSConnectionID, CGWindowID, UnsafeMutablePointer<CGSSpaceID>) -> Int32
    private typealias CGSGetActiveSpaceFunc = @convention(c) (CGSConnectionID) -> CGSSpaceID
    private typealias CGSSetWorkspaceFunc = @convention(c) (CGSConnectionID, CGSSpaceID) -> Void

    // MARK: - Dynamically Loaded Functions
    private var getWindowWorkspace: CGSGetWindowWorkspaceFunc?
    private var getActiveSpace: CGSGetActiveSpaceFunc?
    private var setWorkspace: CGSSetWorkspaceFunc?

    private var skyLightHandle: UnsafeMutableRawPointer?
    private var privateAPIsInitialized = false

    // MARK: - Initialization
    private init() {
        loadPrivateAPIs()
    }

    private func loadPrivateAPIs() {
        // Load SkyLight framework
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY) else {
            print("SpaceManager: Failed to load SkyLight framework")
            return
        }
        skyLightHandle = handle

        // Load CGSGetWindowWorkspace
        if let symbol = dlsym(handle, "CGSGetWindowWorkspace") {
            getWindowWorkspace = unsafeBitCast(symbol, to: CGSGetWindowWorkspaceFunc.self)
        } else {
            print("SpaceManager: Failed to load CGSGetWindowWorkspace")
        }

        // Load CGSGetActiveSpace
        if let symbol = dlsym(handle, "CGSGetActiveSpace") {
            getActiveSpace = unsafeBitCast(symbol, to: CGSGetActiveSpaceFunc.self)
        } else {
            print("SpaceManager: Failed to load CGSGetActiveSpace")
        }

        // Load CGSSetWorkspace
        if let symbol = dlsym(handle, "CGSSetWorkspace") {
            setWorkspace = unsafeBitCast(symbol, to: CGSSetWorkspaceFunc.self)
        } else {
            print("SpaceManager: Failed to load CGSSetWorkspace")
        }

        privateAPIsInitialized = (getWindowWorkspace != nil && getActiveSpace != nil && setWorkspace != nil)
        print("SpaceManager: Private APIs Initialized = \(privateAPIsInitialized)")
    }

    // MARK: - Private API Methods (Space Switching)

    /// Get the space ID for a window
    func spaceForWindow(_ windowID: CGWindowID) -> CGSSpaceID? {
        guard let getWorkspace = getWindowWorkspace else {
            return nil
        }

        let conn = CGSMainConnectionID()
        var spaceID: CGSSpaceID = 0
        let result = getWorkspace(conn, windowID, &spaceID)

        if result == 0 && spaceID != 0 {
            return spaceID
        }
        return nil
    }

    /// Get the currently active space ID
    func activeSpaceID() -> CGSSpaceID? {
        guard let getActive = getActiveSpace else {
            return nil
        }

        let conn = CGSMainConnectionID()
        let spaceID = getActive(conn)
        return spaceID != 0 ? spaceID : nil
    }

    /// Switch to a different space
    func switchToSpace(_ spaceID: CGSSpaceID) {
        guard let setWS = setWorkspace else {
            return
        }

        let conn = CGSMainConnectionID()
        setWS(conn, spaceID)
    }

    /// Check if space management private APIs are available
    var isSpaceSwitchingAvailable: Bool {
        return privateAPIsInitialized
    }
}
```

### 3. AccessibilityWrapper.swift (Window Activation Logic)

```swift
import Cocoa
import ApplicationServices

class AccessibilityWrapper {

    // MARK: - Window Activation

    /// Activate a specific window by PID and window ID
    /// Flow: Check if on current space -> If not, switch spaces -> Wait for AX refresh -> Activate via AX
    func activateWindow(pid: pid_t, windowID: CGWindowID) -> Bool {
        // First, try to find and activate on current space
        if let window = findWindowByID(pid: pid, windowID: windowID) {
            return focusWindow(window, pid: pid)
        }

        // Window not found in current AX list - it's on another space
        // Use SpaceManager to switch to that space first
        return activateWindowOnOtherSpace(pid: pid, windowID: windowID)
    }

    /// Find a window by its CGWindowID in the current AX window list
    private func findWindowByID(pid: pid_t, windowID: CGWindowID) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(pid)

        guard let windows = getWindows(for: appElement) else {
            return nil
        }

        for window in windows {
            var axWindowID: CGWindowID = 0
            if _AXUIElementGetWindow(window, &axWindowID) == .success && axWindowID == windowID {
                return window
            }
        }

        return nil
    }

    /// Activate a window that's on another space by switching spaces first
    private func activateWindowOnOtherSpace(pid: pid_t, windowID: CGWindowID) -> Bool {
        // Get the space manager
        let spaceManager = SpaceManager.shared

        // Get the window's space
        guard let windowSpace = spaceManager.spaceForWindow(windowID) else {
            // Can't determine space - fall back to just activating the app
            return activateAppOnly(pid: pid)
        }

        // Check if we're already on that space
        if let currentSpace = spaceManager.activeSpaceID(), currentSpace == windowSpace {
            // We're on the right space but window not in AX list - might be minimized
            return activateAppOnly(pid: pid)
        }

        // Switch to the window's space
        spaceManager.switchToSpace(windowSpace)

        // Wait for AX to refresh after space switch, then activate the window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.activateWindowViaAX(pid: pid, windowID: windowID)
        }

        return true
    }

    /// Activate a window via Accessibility API (call only after space is active)
    private func activateWindowViaAX(pid: pid_t, windowID: CGWindowID) {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return }

        let appElement = AXUIElementCreateApplication(pid)

        guard let windows = getWindows(for: appElement) else {
            app.activate(options: [.activateIgnoringOtherApps])
            return
        }

        // Find the window with matching ID
        for window in windows {
            var axWindowID: CGWindowID = 0
            if _AXUIElementGetWindow(window, &axWindowID) == .success && axWindowID == windowID {
                _ = focusWindow(window, pid: pid)
                return
            }
        }

        // Window not found - just activate the app
        app.activate(options: [.activateIgnoringOtherApps])
    }

    /// Focus a specific window element
    func focusWindow(_ windowElement: AXUIElement, pid: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            return false
        }

        reopenApp(app)
        let activated = app.activate(options: [.activateIgnoringOtherApps])

        if !activated {
            return false
        }

        // Raise the window
        let raiseResult = AXUIElementPerformAction(windowElement, kAXRaiseAction as CFString)

        // Also try setting it as the main window
        AXUIElementSetAttributeValue(windowElement, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(windowElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)

        return raiseResult == .success || activated
    }

    /// Activate app without specific window
    func activateAppOnly(pid: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            return false
        }
        reopenApp(app)
        return app.activate(options: [.activateIgnoringOtherApps])
    }

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

    /// Get all windows for an application
    func getWindows(for appElement: AXUIElement) -> [AXUIElement]? {
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowsRef
        )
        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            return nil
        }
        return windows
    }
}
```

### 4. WindowManager.swift (Calls Activation)

```swift
// MARK: - Window Activation

func activateWindow(_ window: WindowInfo) -> Bool {
    // Use window ID for activation - works across spaces
    return accessibilityWrapper.activateWindow(pid: window.ownerPID, windowID: window.id)
}
```

## Possible Issues We Suspect

1. **Are the private APIs actually being loaded?**
   - We print `SpaceManager: Private APIs Initialized = true/false` but haven't verified output
   - Maybe `dlsym` is returning the wrong function or nil

2. **Is `CGSGetWindowWorkspace` returning the correct space ID?**
   - Maybe it returns 0 or nil for windows on other spaces
   - Function signature might be wrong

3. **Is `CGSSetWorkspace` actually switching spaces?**
   - Maybe it requires additional parameters
   - Maybe it's deprecated in newer macOS versions (Sequoia 15.x)

4. **Is `CGSGetActiveSpace` returning the correct current space?**
   - Maybe we're comparing wrong values

5. **Function signatures might be wrong:**
   - `CGSGetWindowWorkspace` - we use `(CGSConnectionID, CGWindowID, UnsafeMutablePointer<CGSSpaceID>) -> Int32`
   - `CGSGetActiveSpace` - we use `(CGSConnectionID) -> CGSSpaceID`
   - `CGSSetWorkspace` - we use `(CGSConnectionID, CGSSpaceID) -> Void`

## Questions for Debugging

1. Are these the correct function signatures for macOS Sequoia 15.x?

2. Is there a different API we should use instead of `CGSSetWorkspace`? Perhaps:
   - `CGSManagedDisplaySetCurrentSpace`?
   - `SLSMoveWindowsToManagedSpace`?
   - Something with Mission Control?

3. Should we be using `CGSSpaceID` (uint64_t) or a different type?

4. Do we need to call `CGSManagedDisplaySetCurrentSpace` instead of `CGSSetWorkspace` for modern macOS?

5. How does AltTab (open source) or Contexts actually implement this?

## Environment

- macOS Sequoia 15.x
- Xcode 17
- Swift 5
- App is NOT sandboxed
- Accessibility permission is granted

## What We Need

The correct way to:
1. Get which Space a window is on (by CGWindowID)
2. Switch to that Space programmatically
3. Then activate the specific window

This should work like Contexts app - select any window from any Space and it takes you there.
