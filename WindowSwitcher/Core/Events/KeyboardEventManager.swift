import Cocoa
import Carbon

// MARK: - Protocols

protocol KeyboardEventDelegate: AnyObject {
    func controlSpacePressed()
    func commandTabPressed(withShift: Bool)
    func commandReleased()
    func escapePressed()
}

// MARK: - KeyboardEventManager

class KeyboardEventManager {

    // MARK: - Properties

    weak var delegate: KeyboardEventDelegate?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isCommandHeld = false

    // Configuration
    var enableCommandTabOverride = true
    var enableControlSpace = true

    // MARK: - Lifecycle

    func startMonitoring() {
        // Event mask for key events and modifier changes
        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        // Store reference to self for the callback
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        // Create event tap with a C-compatible callback
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: keyboardEventCallback,
            userInfo: userInfo
        )

        guard let eventTap = eventTap else {
            print("KeyboardEventManager: Failed to create event tap. Check Accessibility permissions.")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        print("KeyboardEventManager: Started monitoring")
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

        print("KeyboardEventManager: Stopped monitoring")
    }

    // MARK: - Event Handling

    fileprivate func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable tap if it was disabled
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Handle modifier key changes (for Command release detection)
        if type == .flagsChanged {
            return handleFlagsChanged(keyCode: keyCode, flags: flags, event: event)
        }

        // Handle key down events
        if type == .keyDown {
            return handleKeyDown(keyCode: keyCode, flags: flags, event: event)
        }

        return Unmanaged.passRetained(event)
    }

    private func handleFlagsChanged(keyCode: Int64, flags: CGEventFlags, event: CGEvent) -> Unmanaged<CGEvent>? {
        let wasCommandHeld = isCommandHeld
        isCommandHeld = flags.contains(.maskCommand)

        // Command key released
        if wasCommandHeld && !isCommandHeld {
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.commandReleased()
            }
        }

        return Unmanaged.passRetained(event)
    }

    private func handleKeyDown(keyCode: Int64, flags: CGEventFlags, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Control-Space: Show search switcher
        if enableControlSpace && keyCode == kVK_Space && flags.contains(.maskControl) {
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.controlSpacePressed()
            }
            return nil // Consume the event
        }

        // Command-Tab: Override system tab switcher
        if enableCommandTabOverride && keyCode == kVK_Tab && flags.contains(.maskCommand) {
            let withShift = flags.contains(.maskShift)
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.commandTabPressed(withShift: withShift)
            }
            return nil // Consume the event
        }

        // Escape: Close switcher
        if keyCode == kVK_Escape {
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.escapePressed()
            }
            // Don't consume - let app handle it too
            return Unmanaged.passRetained(event)
        }

        return Unmanaged.passRetained(event)
    }
}

// MARK: - C-compatible callback function

private func keyboardEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passRetained(event)
    }

    let manager = Unmanaged<KeyboardEventManager>.fromOpaque(userInfo).takeUnretainedValue()
    return manager.handleEvent(proxy: proxy, type: type, event: event)
}

// MARK: - Key Codes (Carbon)
// Common key codes from Carbon Events.h
private let kVK_Tab: Int64 = 0x30
private let kVK_Space: Int64 = 0x31
private let kVK_Escape: Int64 = 0x35
private let kVK_Return: Int64 = 0x24
private let kVK_UpArrow: Int64 = 0x7E
private let kVK_DownArrow: Int64 = 0x7D
private let kVK_LeftArrow: Int64 = 0x7B
private let kVK_RightArrow: Int64 = 0x7C
private let kVK_Command: Int64 = 0x37
private let kVK_Shift: Int64 = 0x38
private let kVK_Control: Int64 = 0x3B
private let kVK_Option: Int64 = 0x3A
