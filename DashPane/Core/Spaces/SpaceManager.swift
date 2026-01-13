import Cocoa

class SpaceManager: ObservableObject {

    // MARK: - Published Properties

    @Published var currentSpaceID: Int?
    @Published var allSpaces: [Int] = []

    // MARK: - Properties

    private let windowEnumerator = WindowEnumerator()

    // MARK: - Space Detection

    /// Check if "Displays have separate Spaces" is enabled in System Preferences
    var displaysHaveSeparateSpaces: Bool {
        return NSScreen.screensHaveSeparateSpaces
    }

    /// Get the number of visible spaces
    var spaceCount: Int {
        return allSpaces.count
    }

    // MARK: - Window Filtering

    /// Filter windows to only those on the current Space
    func filterWindowsForCurrentSpace(_ windows: [WindowInfo]) -> [WindowInfo] {
        let onScreenIDs = windowEnumerator.getOnScreenWindowIDs()
        return windows.filter { onScreenIDs.contains($0.id) }
    }

    /// Check if a window is on the current Space
    func isWindowOnCurrentSpace(_ window: WindowInfo) -> Bool {
        let onScreenIDs = windowEnumerator.getOnScreenWindowIDs()
        return onScreenIDs.contains(window.id)
    }

    /// Group windows by their visibility on current Space
    func groupWindowsBySpaceVisibility(_ windows: [WindowInfo]) -> (currentSpace: [WindowInfo], otherSpaces: [WindowInfo]) {
        let onScreenIDs = windowEnumerator.getOnScreenWindowIDs()

        var currentSpace: [WindowInfo] = []
        var otherSpaces: [WindowInfo] = []

        for window in windows {
            if onScreenIDs.contains(window.id) {
                currentSpace.append(window)
            } else {
                otherSpaces.append(window)
            }
        }

        return (currentSpace, otherSpaces)
    }

    // MARK: - Space Changes

    /// Called when the active Space changes
    func handleSpaceChange() {
        // Refresh any cached Space information
        // This is called by AppDelegate when it receives
        // NSWorkspace.activeSpaceDidChangeNotification
    }

    // MARK: - Private API Notes

    /*
     Note: There is no public API for Space management in macOS.

     To get more detailed Space information, you would need to use private APIs:

     1. CGSCopySpaces - Returns array of Space IDs
        Declaration (bridging header):
        extern CFArrayRef CGSCopySpaces(CGSConnectionID cid, CGSSpaceMask mask);

     2. CGSMainConnectionID - Gets the connection ID
        Declaration (bridging header):
        extern CGSConnectionID CGSMainConnectionID(void);

     3. Space masks:
        - CGSSpaceMask(0x1) - Current Space
        - CGSSpaceMask(0x7) - All Spaces

     Using these would require:
     - A bridging header with the declarations
     - Linking against CoreGraphics
     - Accepting that this is undocumented and may break in future macOS versions

     For a production app, the current approach (using onScreen window filtering)
     is more stable and doesn't rely on private APIs.
     */
}

// MARK: - Space Info Model

struct SpaceInfo: Identifiable, Hashable {
    let id: Int
    let displayID: CGDirectDisplayID
    let isCurrentSpace: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SpaceInfo, rhs: SpaceInfo) -> Bool {
        return lhs.id == rhs.id
    }
}
