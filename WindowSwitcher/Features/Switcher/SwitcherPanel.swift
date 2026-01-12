import Cocoa
import SwiftUI

class SwitcherPanel: NSPanel {

    // MARK: - Initialization

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 400),
            styleMask: [.fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        configure()
    }

    private func configure() {
        // Window level and behavior
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        // Appearance
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        // Behavior - allow key events
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true

        // No animation for instant switching
        animationBehavior = .none
    }

    // MARK: - Content

    func setContent<Content: View>(_ view: Content) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        contentView = hostingView
    }

    // MARK: - Display

    /// Show panel centered on the screen containing the mouse cursor
    func showCentered() {
        guard let screen = screenWithMouse ?? NSScreen.main else { return }
        centerOnScreen(screen)
        orderFrontRegardless()
        makeKeyAndOrderFront(nil)

        // Activate the app to ensure we can receive key events
        NSApp.activate(ignoringOtherApps: true)

        // Focus the first responder (search field)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.makeFirstResponder(self.contentView)
        }
    }

    /// Show panel centered on a specific screen
    func showOnScreen(_ screen: NSScreen) {
        centerOnScreen(screen)
        orderFrontRegardless()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Show panel on all displays (useful for multi-monitor setups)
    func showOnAllDisplays() {
        // For now, show on the screen with the mouse
        showCentered()
    }

    /// Hide the panel
    func hidePanel() {
        orderOut(nil)
    }

    // MARK: - Positioning

    private func centerOnScreen(_ screen: NSScreen) {
        let screenFrame = screen.visibleFrame
        let panelSize = frame.size

        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.midY - panelSize.height / 2

        setFrameOrigin(NSPoint(x: x, y: y))
    }

    private var screenWithMouse: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        }
    }

    // MARK: - Key Events

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // Note: We don't override keyDown here because the SwiftUI hosting view
    // handles keyboard input through the responder chain automatically.
    // Overriding it and forwarding to contentView causes infinite recursion.
}
