import Cocoa
import SwiftUI
import Combine

class SidebarController: ObservableObject {

    // MARK: - Published Properties

    @Published var isVisible = false
    @Published var groupedWindows: [String: [WindowInfo]] = [:]
    @Published var appNamesInMRUOrder: [String] = []
    @Published var currentEdge: ScreenEdge = .left

    // MARK: - Properties

    private let windowManager: WindowManager
    private var panels: [NSScreen: SidebarPanel] = [:]
    private var cancellables = Set<AnyCancellable>()

    // Configuration
    var preferredEdge: ScreenEdge = .left
    var showOnAllDisplays = false

    // MARK: - Initialization

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
        setupBindings()
    }

    private func setupBindings() {
        // Update grouped windows when window list changes
        windowManager.$windows
            .sink { [weak self] windows in
                self?.updateGroupedWindows(windows)
            }
            .store(in: &cancellables)
    }

    // MARK: - Visibility

    func show(on edge: ScreenEdge? = nil) {
        let targetEdge = edge ?? preferredEdge
        currentEdge = targetEdge

        // Refresh windows
        windowManager.refreshWindows()

        if showOnAllDisplays {
            showOnAllScreens(edge: targetEdge)
        } else {
            showOnCurrentScreen(edge: targetEdge)
        }

        isVisible = true
    }

    func hide() {
        for (_, panel) in panels {
            panel.hidePanel()
        }
        isVisible = false
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    // MARK: - Panel Management

    private func showOnCurrentScreen(edge: ScreenEdge) {
        guard let screen = screenWithMouse ?? NSScreen.main else { return }
        showPanel(on: screen, edge: edge)
    }

    private func showOnAllScreens(edge: ScreenEdge) {
        for screen in NSScreen.screens {
            showPanel(on: screen, edge: edge)
        }
    }

    private func showPanel(on screen: NSScreen, edge: ScreenEdge) {
        let panel = getOrCreatePanel(for: screen)

        let contentView = SidebarView(
            controller: self,
            onWindowSelected: { [weak self] window in
                _ = self?.windowManager.activateWindow(window)
                self?.hide()
            }
        )

        panel.setContent(contentView)
        panel.showOnEdge(edge, screen: screen)
    }

    private func getOrCreatePanel(for screen: NSScreen) -> SidebarPanel {
        if let existing = panels[screen] {
            return existing
        }

        let panel = SidebarPanel(edge: preferredEdge)
        panels[screen] = panel
        return panel
    }

    // MARK: - Window Grouping

    private func updateGroupedWindows(_ windows: [WindowInfo]) {
        // Group windows by app name
        groupedWindows = Dictionary(grouping: windows) { $0.ownerName }

        // Build MRU order for apps based on first appearance in the MRU-sorted window list
        var seenApps = Set<String>()
        var mruOrder: [String] = []

        for window in windows {
            if !seenApps.contains(window.ownerName) {
                seenApps.insert(window.ownerName)
                mruOrder.append(window.ownerName)
            }
        }

        appNamesInMRUOrder = mruOrder
    }

    func windowsForApp(_ appName: String) -> [WindowInfo] {
        return groupedWindows[appName] ?? []
    }

    func sortedAppNames() -> [String] {
        return appNamesInMRUOrder
    }

    // MARK: - Helpers

    private var screenWithMouse: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        }
    }
}
