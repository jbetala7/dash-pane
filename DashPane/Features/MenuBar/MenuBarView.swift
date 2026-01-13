import SwiftUI

struct MenuBarView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Quick Actions
            Button(action: showSwitcher) {
                Label("Show Switcher", systemImage: "rectangle.stack")
            }
            .keyboardShortcut(.space, modifiers: .control)

            Button(action: showSidebar) {
                Label("Show Sidebar", systemImage: "sidebar.left")
            }

            Divider()

            // Status
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Monitoring active")
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Settings & Quit
            Button(action: openSettings) {
                Label("Settings...", systemImage: "gear")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button(action: checkForUpdates) {
                Label("Check for Updates...", systemImage: "arrow.clockwise")
            }

            Divider()

            Button(role: .destructive, action: quitApp) {
                Label("Quit DashPane", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    // MARK: - Actions

    private func showSwitcher() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.showSwitcher()
        }
    }

    private func showSidebar() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.toggleSidebar()
        }
    }

    private func checkForUpdates() {
        // Implement update checking
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Status Bar Manager

class StatusBarManager {
    static let shared = StatusBarManager()

    private var statusItem: NSStatusItem?

    private init() {}

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "rectangle.stack", accessibilityDescription: "DashPane")
        }
    }

    func updateIcon(active: Bool) {
        if let button = statusItem?.button {
            let imageName = active ? "rectangle.stack.fill" : "rectangle.stack"
            button.image = NSImage(systemSymbolName: imageName, accessibilityDescription: "DashPane")
        }
    }
}

// MARK: - Preview

#Preview {
    MenuBarView()
        .frame(width: 250)
}
