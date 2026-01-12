import Cocoa

// MARK: - Enums

enum ScreenEdge {
    case left
    case right
    case top
    case bottom
}

enum ScrollDirection {
    case up
    case down
    case left
    case right
}

// MARK: - Protocol

protocol GestureEventDelegate: AnyObject {
    func edgeScrollDetected(edge: ScreenEdge, direction: ScrollDirection)
}

// MARK: - GestureEventManager

class GestureEventManager {

    // MARK: - Properties

    weak var delegate: GestureEventDelegate?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Configuration
    var edgeThreshold: CGFloat = 20.0  // pixels from edge (reduced for easier trigger)
    var scrollThreshold: CGFloat = 3.0 // minimum scroll delta to trigger
    var enabled = true

    // Gesture state
    fileprivate var isGestureActive = false
    fileprivate var accumulatedScrollDelta: CGFloat = 0
    fileprivate let triggerThreshold: CGFloat = 15.0  // reduced for easier trigger

    // MARK: - Lifecycle

    func startMonitoring() {
        let eventMask: CGEventMask = (1 << CGEventType.scrollWheel.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: gestureEventCallback,
            userInfo: userInfo
        )

        guard let eventTap = eventTap else {
            print("GestureEventManager: Failed to create event tap")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        print("GestureEventManager: Started monitoring")
    }

    func stopMonitoring() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil

        print("GestureEventManager: Stopped monitoring")
    }

    // MARK: - Event Handling

    fileprivate func handleScrollEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable tap if needed
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        guard enabled else {
            return Unmanaged.passRetained(event)
        }

        // Check if this is a trackpad scroll (not mouse wheel)
        let scrollPhase = event.getIntegerValueField(.scrollWheelEventScrollPhase)

        // Phase 0 = mouse wheel, non-zero = trackpad gesture
        // Phases: 1=began, 2=changed, 4=ended, 8=cancelled, 128=mayBegin
        guard scrollPhase != 0 else {
            return Unmanaged.passRetained(event)
        }

        // Get cursor position
        let cursorLocation = NSEvent.mouseLocation

        // Check if cursor is near screen edge
        guard let screen = screenContainingPoint(cursorLocation) else {
            return Unmanaged.passRetained(event)
        }

        let screenFrame = screen.frame
        let edge = detectEdge(cursorLocation: cursorLocation, screenFrame: screenFrame)

        guard let detectedEdge = edge else {
            resetGestureState()
            return Unmanaged.passRetained(event)
        }

        // Get scroll deltas
        let deltaY = CGFloat(event.getDoubleValueField(.scrollWheelEventDeltaAxis1))
        let deltaX = CGFloat(event.getDoubleValueField(.scrollWheelEventDeltaAxis2))

        // Handle gesture phases
        if scrollPhase == 1 { // Began
            isGestureActive = true
            accumulatedScrollDelta = 0
        }

        if isGestureActive {
            // Accumulate scroll based on edge
            switch detectedEdge {
            case .left, .right:
                accumulatedScrollDelta += abs(deltaY)
            case .top, .bottom:
                accumulatedScrollDelta += abs(deltaX)
            }

            // Check if we've accumulated enough scroll to trigger
            if accumulatedScrollDelta >= triggerThreshold {
                let direction = determineScrollDirection(deltaX: deltaX, deltaY: deltaY)

                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.edgeScrollDetected(edge: detectedEdge, direction: direction)
                }

                // Reset to prevent repeated triggers
                accumulatedScrollDelta = 0

                // Consume the event
                return nil
            }
        }

        // Check for gesture end
        if scrollPhase == 4 || scrollPhase == 8 { // Ended or Cancelled
            resetGestureState()
        }

        return Unmanaged.passRetained(event)
    }

    // MARK: - Helpers

    private func detectEdge(cursorLocation: NSPoint, screenFrame: NSRect) -> ScreenEdge? {
        let leftDistance = cursorLocation.x - screenFrame.minX
        let rightDistance = screenFrame.maxX - cursorLocation.x
        let topDistance = screenFrame.maxY - cursorLocation.y
        let bottomDistance = cursorLocation.y - screenFrame.minY

        if leftDistance < edgeThreshold {
            return .left
        } else if rightDistance < edgeThreshold {
            return .right
        } else if topDistance < edgeThreshold {
            return .top
        } else if bottomDistance < edgeThreshold {
            return .bottom
        }

        return nil
    }

    private func determineScrollDirection(deltaX: CGFloat, deltaY: CGFloat) -> ScrollDirection {
        if abs(deltaY) > abs(deltaX) {
            return deltaY > 0 ? .up : .down
        } else {
            return deltaX > 0 ? .left : .right
        }
    }

    private func screenContainingPoint(_ point: NSPoint) -> NSScreen? {
        return NSScreen.screens.first { screen in
            screen.frame.contains(point)
        }
    }

    fileprivate func resetGestureState() {
        isGestureActive = false
        accumulatedScrollDelta = 0
    }
}

// MARK: - C-compatible callback function

private func gestureEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passRetained(event)
    }

    let manager = Unmanaged<GestureEventManager>.fromOpaque(userInfo).takeUnretainedValue()
    return manager.handleScrollEvent(type: type, event: event)
}
