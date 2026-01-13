import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var permissionsManager: PermissionsManager!
    private var windowManager: WindowManager!
    private var keyboardEventManager: KeyboardEventManager!
    private var gestureEventManager: GestureEventManager!
    private var switcherController: SwitcherController!
    private var sidebarController: SidebarController!

    private var permissionsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var isHandlingPermissionChange = false

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("DashPane: applicationDidFinishLaunching")

        // Setup status bar item
        setupStatusBar()

        // Initialize managers
        permissionsManager = PermissionsManager()
        windowManager = WindowManager()
        keyboardEventManager = KeyboardEventManager()
        gestureEventManager = GestureEventManager()
        switcherController = SwitcherController(windowManager: windowManager)
        sidebarController = SidebarController(windowManager: windowManager)

        // Set up event delegates
        keyboardEventManager.delegate = self
        gestureEventManager.delegate = self

        // Listen for permission changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePermissionRevoked),
            name: .accessibilityPermissionRevoked,
            object: nil
        )

        // Check permissions on launch
        checkPermissions()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        keyboardEventManager.stopMonitoring()
        gestureEventManager.stopMonitoring()
        permissionsManager.stopContinuousPermissionMonitoring()
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        NSLog("DashPane: Setting up status bar")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            if let menuBarIcon = NSImage(named: "MenuBarIcon") {
                menuBarIcon.isTemplate = true
                button.image = menuBarIcon
            } else {
                // Fallback to system symbol
                button.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "DashPane")
            }
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            NSLog("DashPane: Status bar button configured")
        }

        // Create menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Switcher (Ctrl+Space)", action: #selector(showSwitcherAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Show Sidebar", action: #selector(showSidebarAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Restart Keyboard Shortcuts", action: #selector(restartKeyboardAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Check Permissions...", action: #selector(showPermissionsAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettingsAction), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit DashPane", action: #selector(quitAction), keyEquivalent: "q"))

        statusItem?.menu = menu
        NSLog("DashPane: Status bar menu configured")
    }

    @objc private func statusBarButtonClicked() {
        NSLog("DashPane: Status bar clicked")
    }

    @objc private func showSwitcherAction() {
        showSwitcher()
    }

    @objc private func showSidebarAction() {
        toggleSidebar()
    }

    @objc private func restartKeyboardAction() {
        NSLog("DashPane: Restarting keyboard monitoring")
        keyboardEventManager.stopMonitoring()
        gestureEventManager.stopMonitoring()
        keyboardEventManager.startMonitoring()
        gestureEventManager.startMonitoring()
        NSLog("DashPane: Keyboard monitoring restarted")
    }

    @objc private func showPermissionsAction() {
        showPermissionsWindow()
    }

    @objc private func showSettingsAction() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Permissions

    private func checkPermissions() {
        let hasAccessibility = permissionsManager.checkAccessibilityPermission()
        NSLog("DashPane: Checking permissions - Accessibility: \(hasAccessibility)")

        if hasAccessibility {
            // Permissions granted, start monitoring
            NSLog("DashPane: Accessibility permission granted, starting monitoring")
            startMonitoring()
        } else {
            // No permission - show permissions window
            // This handles both first-time setup and rebuild scenarios
            NSLog("DashPane: No accessibility permission, showing permissions window")
            showPermissionsWindow()

            // Also try to start monitoring - it will fail silently but
            // the permissions window will detect when permission is granted
            startMonitoring()
        }
    }

    private func showPermissionsWindow() {
        // If window already exists and is visible, just bring it to front
        if let existingWindow = permissionsWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Close any existing window first
        permissionsWindow?.close()
        permissionsWindow = nil

        let contentView = PermissionsView(
            permissionsManager: permissionsManager,
            onPermissionsGranted: { [weak self] in
                // Defer window close to next run loop to avoid issues with
                // closing the window while SwiftUI button callback is still executing
                DispatchQueue.main.async {
                    self?.permissionsWindow?.close()
                    self?.permissionsWindow = nil
                    // Monitoring was already started, but restart to ensure event taps work
                    self?.startMonitoring()
                }
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 580),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "DashPane - Permissions Required"
        window.isReleasedWhenClosed = false  // Prevent issues when window is closed
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        permissionsWindow = window
    }

    private func startMonitoring() {
        NSLog("DashPane: Starting monitoring")
        keyboardEventManager.startMonitoring()
        gestureEventManager.startMonitoring()

        // Start continuous permission monitoring to detect revocation
        permissionsManager.startContinuousPermissionMonitoring()

        // Delay window monitoring to avoid initialization crashes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.windowManager.startMonitoring()
        }
    }

    private func stopMonitoring() {
        NSLog("DashPane: Stopping monitoring")
        keyboardEventManager.stopMonitoring()
        gestureEventManager.stopMonitoring()
        windowManager.stopMonitoring()
        permissionsManager.stopContinuousPermissionMonitoring()
    }

    @objc private func handlePermissionRevoked() {
        // Prevent duplicate handling from multiple notification sources
        guard !isHandlingPermissionChange else {
            NSLog("DashPane: Ignoring duplicate permission revoked notification")
            return
        }
        isHandlingPermissionChange = true

        NSLog("DashPane: Accessibility permission revoked! Stopping event monitoring immediately.")

        // All operations must happen on main thread for thread safety
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // CRITICAL: Stop monitoring immediately to prevent keyboard lockup
            self.stopMonitoring()

            // Show permissions window so user knows what happened
            self.showPermissionsWindow()

            // Reset flag after a short delay to allow for stabilization
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.isHandlingPermissionChange = false
            }
        }
    }

    // MARK: - Public Methods

    func showSwitcher() {
        NSLog("DashPane: showSwitcher called")
        switcherController.show()
    }

    func hideSwitcher() {
        switcherController.hide()
    }

    func toggleSidebar() {
        sidebarController.toggle()
    }
}

// MARK: - KeyboardEventDelegate

extension AppDelegate: KeyboardEventDelegate {

    // Track state for delayed UI show
    private static var tabPressCount = 0
    private static var showUITimer: Timer?
    private static var isQuickSwitching = false

    func controlSpacePressed() {
        NSLog("DashPane: Control+Space pressed")
        if switcherController.isVisible {
            switcherController.hide()
        } else {
            // Show in search mode (with search bar focused)
            switcherController.show(searchMode: true)
        }
    }

    func commandTabPressed(withShift: Bool) {
        NSLog("DashPane: Command+Tab pressed (count: \(AppDelegate.tabPressCount + 1))")

        AppDelegate.tabPressCount += 1

        if AppDelegate.tabPressCount == 1 {
            // First Tab press - prepare windows but don't show UI yet
            AppDelegate.isQuickSwitching = true
            switcherController.prepareForQuickSwitch()

            if withShift {
                switcherController.selectPrevious()
            } else {
                switcherController.selectNext()
            }

            // Start timer to show UI if Command is held
            AppDelegate.showUITimer?.invalidate()
            AppDelegate.showUITimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: false) { [weak self] _ in
                guard let self = self, AppDelegate.isQuickSwitching else { return }
                AppDelegate.isQuickSwitching = false
                // Command still held - show the UI
                self.switcherController.show(searchMode: false)
            }
        } else {
            // Multiple Tab presses - show UI immediately
            AppDelegate.showUITimer?.invalidate()
            AppDelegate.isQuickSwitching = false

            if !switcherController.isVisible {
                switcherController.show(searchMode: false)
            }

            if withShift {
                switcherController.selectPrevious()
            } else {
                switcherController.selectNext()
            }
        }
    }

    func commandReleased() {
        NSLog("DashPane: Command released (quickSwitch: \(AppDelegate.isQuickSwitching), visible: \(switcherController.isVisible))")

        // Cancel the show UI timer
        AppDelegate.showUITimer?.invalidate()
        AppDelegate.showUITimer = nil

        if AppDelegate.isQuickSwitching {
            // Quick switch - activate without ever showing UI
            AppDelegate.isQuickSwitching = false
            switcherController.activateSelectedQuick()
        } else if switcherController.isVisible && !switcherController.isSearchMode {
            // Normal mode - UI was shown, activate selected
            switcherController.activateSelectedAndHide()
        }

        // Reset tab count
        AppDelegate.tabPressCount = 0
    }

    func escapePressed() {
        AppDelegate.showUITimer?.invalidate()
        AppDelegate.isQuickSwitching = false
        AppDelegate.tabPressCount = 0

        if switcherController.isVisible {
            switcherController.hide()
        }
    }
}

// MARK: - GestureEventDelegate

extension AppDelegate: GestureEventDelegate {
    func edgeScrollDetected(edge: ScreenEdge, direction: ScrollDirection) {
        sidebarController.show(on: edge)
    }
}
