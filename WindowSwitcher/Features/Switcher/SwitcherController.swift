import Cocoa
import SwiftUI
import Combine

/// Display item type - can be a section header or a window item
enum DisplayItemType: Equatable {
    case sectionHeader(title: String)
    case windowItem(window: WindowInfo, shortcut: String)
}

/// Display item with type and unique ID
struct DisplayItem: Identifiable {
    let id: String
    let type: DisplayItemType

    var isHeader: Bool {
        if case .sectionHeader = type { return true }
        return false
    }

    var window: WindowInfo? {
        if case .windowItem(let window, _) = type { return window }
        return nil
    }

    var shortcut: String {
        if case .windowItem(_, let shortcut) = type { return shortcut }
        return ""
    }
}

class SwitcherController: ObservableObject {

    // MARK: - Published Properties

    @Published var isVisible = false
    @Published var isSearchMode = false  // true for Ctrl+Space, false for Cmd+Tab
    @Published var searchText = "" {
        didSet {
            // Immediately update results when search text changes
            updateFilteredResults(searchText: searchText, windows: windowManager.windows)
        }
    }
    @Published var selectedIndex = 0
    @Published var filteredResults: [SearchResult] = []
    @Published var displayItems: [DisplayItem] = []

    // MARK: - Properties

    private let windowManager: WindowManager
    private let searchEngine = FuzzySearchEngine()
    private var panel: SwitcherPanel?
    private var cancellables = Set<AnyCancellable>()
    private var localEventMonitor: Any?

    // Shortcut mapping for quick lookup
    private var shortcutMap: [String: Int] = [:]

    // MARK: - Initialization

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
        setupBindings()
    }

    private func setupBindings() {
        // Update filtered results when windows change
        windowManager.$windows
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] windows in
                guard let self = self else { return }
                self.updateFilteredResults(searchText: self.searchText, windows: windows)
            }
            .store(in: &cancellables)
    }

    // MARK: - Visibility

    func show(searchMode: Bool = true) {
        if panel == nil {
            createPanel()
        }

        // Refresh windows
        windowManager.refreshWindows()

        // Set mode
        isSearchMode = searchMode

        // Reset state
        searchText = ""
        selectedIndex = 0
        updateFilteredResults(searchText: "", windows: windowManager.windows)

        // Show panel
        panel?.showCentered()
        isVisible = true

        // Focus search field if in search mode
        // The KeyHandlingTextField handles its own focus via makeNSView

        // Start monitoring for shortcut keys when not in search mode
        if !searchMode {
            startLocalKeyMonitor()
        }
    }

    func hide() {
        panel?.hidePanel()
        isVisible = false
        searchText = ""
        isSearchMode = false
        stopLocalKeyMonitor()
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    // MARK: - Local Key Monitor (for shortcut keys in cycle mode)

    private func startLocalKeyMonitor() {
        stopLocalKeyMonitor()  // Ensure no duplicate monitors

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible, !self.isSearchMode else {
                return event
            }

            // Get the character pressed
            if let chars = event.charactersIgnoringModifiers?.lowercased(), !chars.isEmpty {
                // Check if pressing a shortcut sequence
                if self.activateByShortcutKey(chars) {
                    return nil  // Consume the event
                }
            }

            // Handle Escape
            if event.keyCode == 53 {  // Escape
                self.hide()
                return nil
            }

            // Handle arrow keys
            if event.keyCode == 125 {  // Down arrow
                self.selectNext()
                return nil
            }
            if event.keyCode == 126 {  // Up arrow
                self.selectPrevious()
                return nil
            }

            // Handle Enter/Return
            if event.keyCode == 36 {  // Return
                self.activateSelectedAndHide()
                return nil
            }

            return event
        }
    }

    private func stopLocalKeyMonitor() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }

    // MARK: - Navigation

    /// Find the next selectable (non-header) index
    private func nextSelectableIndex(from index: Int) -> Int {
        guard !displayItems.isEmpty else { return 0 }
        var next = (index + 1) % displayItems.count
        var iterations = 0
        while displayItems[next].isHeader && iterations < displayItems.count {
            next = (next + 1) % displayItems.count
            iterations += 1
        }
        return next
    }

    /// Find the previous selectable (non-header) index
    private func previousSelectableIndex(from index: Int) -> Int {
        guard !displayItems.isEmpty else { return 0 }
        var prev = index > 0 ? index - 1 : displayItems.count - 1
        var iterations = 0
        while displayItems[prev].isHeader && iterations < displayItems.count {
            prev = prev > 0 ? prev - 1 : displayItems.count - 1
            iterations += 1
        }
        return prev
    }

    /// Find the first selectable index
    private func firstSelectableIndex() -> Int {
        for (index, item) in displayItems.enumerated() {
            if !item.isHeader { return index }
        }
        return 0
    }

    func selectNext() {
        guard !displayItems.isEmpty else { return }
        selectedIndex = nextSelectableIndex(from: selectedIndex)
    }

    func selectPrevious() {
        guard !displayItems.isEmpty else { return }
        selectedIndex = previousSelectableIndex(from: selectedIndex)
    }

    func selectIndex(_ index: Int) {
        guard index >= 0 && index < displayItems.count && !displayItems[index].isHeader else { return }
        selectedIndex = index
    }

    // MARK: - Quick Switch (no UI)

    /// Prepare for quick switch - load windows without showing UI
    func prepareForQuickSwitch() {
        // Refresh windows
        windowManager.refreshWindows()

        // Reset state
        searchText = ""
        selectedIndex = 0
        updateFilteredResults(searchText: "", windows: windowManager.windows)
    }

    /// Activate selected window without UI (for quick Command+Tab release)
    func activateSelectedQuick() {
        guard selectedIndex < displayItems.count,
              let window = displayItems[selectedIndex].window else { return }
        _ = windowManager.activateWindow(window)
    }

    // MARK: - Activation

    func activateSelected() {
        guard selectedIndex < displayItems.count,
              let window = displayItems[selectedIndex].window else { return }
        _ = windowManager.activateWindow(window)
    }

    func activateSelectedAndHide() {
        guard selectedIndex < displayItems.count,
              let window = displayItems[selectedIndex].window else { return }

        // Hide immediately, then activate with no delay
        hide()
        _ = windowManager.activateWindow(window)
    }

    func activateWindow(_ window: WindowInfo) {
        // Hide immediately, then activate with no delay
        hide()
        _ = windowManager.activateWindow(window)
    }

    /// Activate window by shortcut key
    /// Returns true if a matching window was found and activated
    @discardableResult
    func activateByShortcutKey(_ key: String) -> Bool {
        let lowercaseKey = key.lowercased()

        // Look up in shortcut map
        if let index = shortcutMap[lowercaseKey] {
            selectIndex(index)
            activateSelectedAndHide()
            return true
        }

        return false
    }

    // MARK: - Search

    func updateSearch(_ text: String) {
        searchText = text
    }

    private func updateFilteredResults(searchText: String, windows: [WindowInfo]) {
        // Remove only truly duplicate windows (same window ID appears multiple times)
        let uniqueWindows = removeDuplicateWindowIDs(windows)

        if searchText.isEmpty {
            // When no search text, show all windows sorted by most recent
            filteredResults = uniqueWindows.map { SearchResult(window: $0, score: 1.0, matchedRanges: []) }
        } else {
            // Apply fuzzy search
            filteredResults = searchEngine.search(query: searchText, in: uniqueWindows)
        }

        // Generate display items with shortcuts
        generateDisplayItems()

        // Only reset selection if current index is out of bounds or on a header
        if selectedIndex >= displayItems.count ||
           (selectedIndex < displayItems.count && displayItems[selectedIndex].isHeader) {
            selectedIndex = firstSelectableIndex()
        }
    }

    /// Remove windows with duplicate IDs (keep first occurrence)
    private func removeDuplicateWindowIDs(_ windows: [WindowInfo]) -> [WindowInfo] {
        var seenIDs = Set<CGWindowID>()
        var result: [WindowInfo] = []

        for window in windows {
            if !seenIDs.contains(window.id) {
                seenIDs.insert(window.id)
                result.append(window)
            }
        }

        return result
    }

    /// Generate display items with section headers for desktops/fullscreen
    private func generateDisplayItems() {
        var items: [DisplayItem] = []
        var usedShortcuts: Set<String> = []
        shortcutMap.removeAll()

        // Group windows by category
        let grouped = groupWindowsByCategory(filteredResults.map { $0.window })

        // Determine if we need section headers (multiple groups or fullscreen apps)
        let needsSections = grouped.count > 1 ||
                          grouped.keys.contains(where: { $0.hasPrefix("Full Screen") })

        // Define display order: Current Desktop first, then other desktops, then fullscreen
        let orderedKeys = grouped.keys.sorted { key1, key2 in
            if key1.hasPrefix("Desktop 1") || key1 == "Current Desktop" { return true }
            if key2.hasPrefix("Desktop 1") || key2 == "Current Desktop" { return false }
            if key1.hasPrefix("Full Screen") { return false }
            if key2.hasPrefix("Full Screen") { return true }
            return key1 < key2
        }

        for category in orderedKeys {
            guard let windows = grouped[category] else { continue }

            // Add section header if needed
            if needsSections {
                items.append(DisplayItem(
                    id: "header-\(category)",
                    type: .sectionHeader(title: category)
                ))
            }

            // Add windows
            for window in windows {
                let shortcut = generateUniqueShortcut(for: window.ownerName, usedShortcuts: &usedShortcuts)
                usedShortcuts.insert(shortcut)

                // Store the displayItems index for this shortcut
                let itemIndex = items.count
                shortcutMap[shortcut] = itemIndex

                items.append(DisplayItem(
                    id: "window-\(window.id)",
                    type: .windowItem(window: window, shortcut: shortcut)
                ))
            }
        }

        displayItems = items
    }

    /// Group windows by category (Desktop X, Full Screen)
    private func groupWindowsByCategory(_ windows: [WindowInfo]) -> [String: [WindowInfo]] {
        var groups: [String: [WindowInfo]] = [:]

        // Get current space for comparison
        let enumerator = WindowEnumerator()
        let currentSpaceID = enumerator.getCurrentSpaceID()
        let allSpaceIDs = enumerator.getAllSpaceIDs()

        for window in windows {
            let category: String

            if window.isFullscreen {
                category = "Full Screen"
            } else if let spaceID = window.spaceID {
                // Determine desktop number
                if let spaceIndex = allSpaceIDs.firstIndex(of: UInt64(spaceID)) {
                    category = "Desktop \(spaceIndex + 1)"
                } else if UInt64(spaceID) == currentSpaceID {
                    category = "Desktop 1"
                } else {
                    category = "Desktop 1"
                }
            } else {
                category = "Desktop 1"
            }

            if groups[category] == nil {
                groups[category] = []
            }
            groups[category]?.append(window)
        }

        return groups
    }

    /// Generate a unique SINGLE letter shortcut for an app name
    /// Strategy:
    /// 1. Try first letter of app name
    /// 2. If taken, try other letters from the app name
    /// 3. If all app letters are taken, assign next available letter (a-z, 0-9)
    private func generateUniqueShortcut(for appName: String, usedShortcuts: inout Set<String>) -> String {
        let cleanName = appName.lowercased().filter { $0.isLetter || $0.isNumber }
        let allLetters = "abcdefghijklmnopqrstuvwxyz0123456789"

        guard !cleanName.isEmpty else {
            // Fallback - find any available letter
            for char in allLetters {
                let s = String(char)
                if !usedShortcuts.contains(s) {
                    return s
                }
            }
            return ""
        }

        // Try first letter
        let firstLetter = String(cleanName.prefix(1))
        if !usedShortcuts.contains(firstLetter) {
            return firstLetter
        }

        // Try other letters from the app name
        for char in cleanName {
            let s = String(char)
            if !usedShortcuts.contains(s) {
                return s
            }
        }

        // If all app name letters are taken, find next available letter
        for char in allLetters {
            let s = String(char)
            if !usedShortcuts.contains(s) {
                return s
            }
        }

        // Fallback (should rarely happen)
        return ""
    }

    // MARK: - Panel Creation

    private func createPanel() {
        panel = SwitcherPanel()

        let contentView = SwitcherView(controller: self)
        panel?.setContent(contentView)
    }

    deinit {
        stopLocalKeyMonitor()
    }
}
