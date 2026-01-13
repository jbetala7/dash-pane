import Cocoa
import SwiftUI

class SidebarPanel: NSPanel {

    // MARK: - Properties

    private var trackingArea: NSTrackingArea?
    private var hideTimer: Timer?
    private var edge: ScreenEdge = .left

    var autoHideDelay: TimeInterval = 0.5
    var sidebarWidth: CGFloat = 280

    // MARK: - Initialization

    init(edge: ScreenEdge = .left) {
        self.edge = edge

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 600),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
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

        // Behavior
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true

        // Animation
        animationBehavior = .utilityWindow
    }

    // MARK: - Content

    func setContent<Content: View>(_ view: Content) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        contentView = hostingView

        setupTrackingArea()
    }

    // MARK: - Display

    func showOnEdge(_ edge: ScreenEdge, screen: NSScreen? = nil) {
        self.edge = edge

        guard let targetScreen = screen ?? NSScreen.main else { return }

        positionOnEdge(edge, screen: targetScreen)

        // Animate in
        alphaValue = 0
        orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }

        cancelHideTimer()
    }

    func hidePanel() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.orderOut(nil)
        }
    }

    func hideWithDelay() {
        cancelHideTimer()
        hideTimer = Timer.scheduledTimer(withTimeInterval: autoHideDelay, repeats: false) { [weak self] _ in
            self?.hidePanel()
        }
    }

    private func cancelHideTimer() {
        hideTimer?.invalidate()
        hideTimer = nil
    }

    // MARK: - Positioning

    private func positionOnEdge(_ edge: ScreenEdge, screen: NSScreen) {
        let screenFrame = screen.visibleFrame
        var panelFrame = frame

        panelFrame.size.width = sidebarWidth
        panelFrame.size.height = screenFrame.height

        switch edge {
        case .left:
            panelFrame.origin.x = screenFrame.minX
            panelFrame.origin.y = screenFrame.minY
        case .right:
            panelFrame.origin.x = screenFrame.maxX - sidebarWidth
            panelFrame.origin.y = screenFrame.minY
        case .top:
            // For top edge, use horizontal sidebar
            panelFrame.size.width = screenFrame.width
            panelFrame.size.height = sidebarWidth
            panelFrame.origin.x = screenFrame.minX
            panelFrame.origin.y = screenFrame.maxY - sidebarWidth
        case .bottom:
            panelFrame.size.width = screenFrame.width
            panelFrame.size.height = sidebarWidth
            panelFrame.origin.x = screenFrame.minX
            panelFrame.origin.y = screenFrame.minY
        }

        setFrame(panelFrame, display: true)
    }

    // MARK: - Mouse Tracking

    private func setupTrackingArea() {
        if let existing = trackingArea {
            contentView?.removeTrackingArea(existing)
        }

        guard let contentView = contentView else { return }

        trackingArea = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )

        contentView.addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        cancelHideTimer()
    }

    override func mouseExited(with event: NSEvent) {
        hideWithDelay()
    }

    // MARK: - Key Events

    override var canBecomeKey: Bool { true }
}
