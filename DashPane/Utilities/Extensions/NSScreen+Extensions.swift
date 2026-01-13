import Cocoa

extension NSScreen {

    /// Get the screen containing the mouse cursor
    static var screenWithMouse: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return screens.first { screen in
            screen.frame.contains(mouseLocation)
        }
    }

    /// Get the screen for a specific display ID
    static func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        return screens.first { screen in
            screen.displayID == displayID
        }
    }

    /// Get the display ID for this screen
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? 0
    }

    /// Get the display name
    var displayName: String {
        return localizedName
    }

    /// Check if this is the primary display (with menu bar)
    var isPrimary: Bool {
        return frame.origin == .zero
    }

    /// Get visible frame in global coordinates
    var visibleFrameGlobal: CGRect {
        return visibleFrame
    }

    /// Convert point from global screen coordinates to this screen's local coordinates
    func convertFromGlobal(_ point: NSPoint) -> NSPoint {
        return NSPoint(
            x: point.x - frame.origin.x,
            y: point.y - frame.origin.y
        )
    }

    /// Convert point from this screen's local coordinates to global screen coordinates
    func convertToGlobal(_ point: NSPoint) -> NSPoint {
        return NSPoint(
            x: point.x + frame.origin.x,
            y: point.y + frame.origin.y
        )
    }

    /// Get all screens sorted by position (left to right, then top to bottom)
    static var sortedScreens: [NSScreen] {
        return screens.sorted { screen1, screen2 in
            if screen1.frame.origin.x != screen2.frame.origin.x {
                return screen1.frame.origin.x < screen2.frame.origin.x
            }
            return screen1.frame.origin.y > screen2.frame.origin.y
        }
    }
}
