import Foundation
import ServiceManagement
import SwiftUI

class SettingsManager: ObservableObject {

    // MARK: - Singleton

    static let shared = SettingsManager()

    // MARK: - User Defaults Keys

    private enum Keys {
        static let enableCommandTabOverride = "enableCommandTabOverride"
        static let enableControlSpace = "enableControlSpace"
        static let enableGestures = "enableGestures"
        static let sidebarEdge = "sidebarEdge"
        static let sidebarAutoHide = "sidebarAutoHide"
        static let sidebarAutoHideDelay = "sidebarAutoHideDelay"
        static let showWindowsFromAllSpaces = "showWindowsFromAllSpaces"
        static let showMinimizedWindows = "showMinimizedWindows"
        static let launchAtLogin = "launchAtLogin"
        static let gestureEdgeThreshold = "gestureEdgeThreshold"
        static let theme = "theme"
    }

    // MARK: - Published Properties

    // Keyboard Shortcuts
    @Published var enableCommandTabOverride: Bool {
        didSet { UserDefaults.standard.set(enableCommandTabOverride, forKey: Keys.enableCommandTabOverride) }
    }

    @Published var enableControlSpace: Bool {
        didSet { UserDefaults.standard.set(enableControlSpace, forKey: Keys.enableControlSpace) }
    }

    // Gestures
    @Published var enableGestures: Bool {
        didSet { UserDefaults.standard.set(enableGestures, forKey: Keys.enableGestures) }
    }

    @Published var gestureEdgeThreshold: Double {
        didSet { UserDefaults.standard.set(gestureEdgeThreshold, forKey: Keys.gestureEdgeThreshold) }
    }

    // Sidebar
    @Published var sidebarEdge: SidebarEdgeOption {
        didSet { UserDefaults.standard.set(sidebarEdge.rawValue, forKey: Keys.sidebarEdge) }
    }

    @Published var sidebarAutoHide: Bool {
        didSet { UserDefaults.standard.set(sidebarAutoHide, forKey: Keys.sidebarAutoHide) }
    }

    @Published var sidebarAutoHideDelay: Double {
        didSet { UserDefaults.standard.set(sidebarAutoHideDelay, forKey: Keys.sidebarAutoHideDelay) }
    }

    // Windows
    @Published var showWindowsFromAllSpaces: Bool {
        didSet { UserDefaults.standard.set(showWindowsFromAllSpaces, forKey: Keys.showWindowsFromAllSpaces) }
    }

    @Published var showMinimizedWindows: Bool {
        didSet { UserDefaults.standard.set(showMinimizedWindows, forKey: Keys.showMinimizedWindows) }
    }

    // General
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            updateLaunchAtLogin()
        }
    }

    @Published var theme: ThemeOption {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme) }
    }

    // MARK: - Initialization

    private init() {
        // Load saved values or use defaults
        self.enableCommandTabOverride = UserDefaults.standard.object(forKey: Keys.enableCommandTabOverride) as? Bool ?? true
        self.enableControlSpace = UserDefaults.standard.object(forKey: Keys.enableControlSpace) as? Bool ?? true
        self.enableGestures = UserDefaults.standard.object(forKey: Keys.enableGestures) as? Bool ?? true
        self.gestureEdgeThreshold = UserDefaults.standard.object(forKey: Keys.gestureEdgeThreshold) as? Double ?? 50.0

        self.sidebarEdge = SidebarEdgeOption(rawValue: UserDefaults.standard.string(forKey: Keys.sidebarEdge) ?? "") ?? .left
        self.sidebarAutoHide = UserDefaults.standard.object(forKey: Keys.sidebarAutoHide) as? Bool ?? true
        self.sidebarAutoHideDelay = UserDefaults.standard.object(forKey: Keys.sidebarAutoHideDelay) as? Double ?? 0.5

        self.showWindowsFromAllSpaces = UserDefaults.standard.object(forKey: Keys.showWindowsFromAllSpaces) as? Bool ?? true
        self.showMinimizedWindows = UserDefaults.standard.object(forKey: Keys.showMinimizedWindows) as? Bool ?? false

        let savedLaunchAtLogin = UserDefaults.standard.object(forKey: Keys.launchAtLogin) as? Bool
        self.launchAtLogin = savedLaunchAtLogin ?? true
        self.theme = ThemeOption(rawValue: UserDefaults.standard.string(forKey: Keys.theme) ?? "") ?? .system

        // On first launch, save the default value
        if savedLaunchAtLogin == nil {
            UserDefaults.standard.set(true, forKey: Keys.launchAtLogin)
        }

        // Always sync the OS login item state with the stored preference
        updateLaunchAtLogin()
    }

    // MARK: - Launch at Login

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Failed to update launch at login: \(error)")
        }
    }

    // MARK: - Reset to Defaults

    func resetToDefaults() {
        enableCommandTabOverride = true
        enableControlSpace = true
        enableGestures = true
        gestureEdgeThreshold = 50.0
        sidebarEdge = .left
        sidebarAutoHide = true
        sidebarAutoHideDelay = 0.5
        showWindowsFromAllSpaces = true
        showMinimizedWindows = false
        launchAtLogin = false
        theme = .system
    }
}

// MARK: - Options

enum SidebarEdgeOption: String, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        }
    }

    var screenEdge: ScreenEdge {
        switch self {
        case .left: return .left
        case .right: return .right
        }
    }
}

enum ThemeOption: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}
