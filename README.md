# DashPane

A fast, powerful window switcher for macOS - similar to [Contexts](https://contexts.co/).

## Features

- **Fast Search** - Press Control+Space to instantly search and switch windows
- **Command-Tab Replacement** - Override the default Command-Tab to show individual windows
- **Auto-hiding Sidebar** - Edge-triggered sidebar showing all windows grouped by app
- **Gesture Controls** - Two-finger scroll from screen edge to show sidebar
- **Multi-Space Support** - View windows from current Space or all Spaces
- **Multi-Display Support** - Works seamlessly across multiple monitors

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building)

## Permissions Required

DashPane requires the following permissions:

1. **Accessibility** - To enumerate windows and switch between them
2. **Screen Recording** - To capture window thumbnails and titles

## Building from Source

### Option 1: Using Xcode (Recommended)

1. Open Xcode
2. Create a new macOS App project:
   - Product Name: `DashPane`
   - Team: Your development team
   - Organization Identifier: Your identifier (e.g., `com.yourname`)
   - Interface: SwiftUI
   - Language: Swift

3. Copy all files from the `DashPane/` directory into your Xcode project

4. Configure the project:
   - Set deployment target to macOS 13.0
   - Add the bridging header: `DashPane-Bridging-Header.h`
   - Update Info.plist with the provided values
   - Add entitlements from `DashPane.entitlements`

5. Build and run (Cmd+R)

### Option 2: Using Swift Package Manager

```bash
cd DashPane
swift build
```

Note: SPM builds may require additional configuration for the bridging header.

## Project Structure

```
DashPane/
├── App/                    # Main app entry point
│   ├── DashPaneApp.swift
│   ├── AppDelegate.swift
│   └── Info.plist
├── Core/                   # Core functionality
│   ├── Permissions/        # Permission management
│   ├── Windows/           # Window enumeration & management
│   ├── Spaces/            # Space detection
│   ├── Events/            # Keyboard & gesture events
│   └── Search/            # Fuzzy search engine
├── Features/              # UI features
│   ├── Switcher/          # Main switcher panel
│   ├── Sidebar/           # Edge sidebar
│   └── MenuBar/           # Menu bar integration
├── Settings/              # App settings
└── Utilities/             # Helper extensions
```

## Usage

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Control + Space | Open search switcher |
| Command + Tab | Show all windows (when override enabled) |
| Arrow Keys | Navigate window list |
| Enter | Switch to selected window |
| Escape | Close switcher |

### Gestures

- **Two-finger scroll from screen edge** - Shows the sidebar

### Sidebar

The sidebar shows all windows grouped by application. Click any window to switch to it.

## Configuration

Open Settings from the menu bar icon to configure:

- Enable/disable Command-Tab override
- Enable/disable gestures
- Choose sidebar edge (left/right)
- Configure auto-hide behavior
- Show windows from all Spaces or current Space only

## Technical Details

### APIs Used

- **CGWindowListCopyWindowInfo** - Window enumeration
- **AXUIElement** - Window focus and manipulation
- **CGEventTap** - Global keyboard and gesture capture
- **NSPanel** - Floating overlay windows

### Private APIs (Optional)

The bridging header includes declarations for private Space APIs. These are optional and allow for more advanced Space management features.

## Distribution

### Notarization

For distribution outside the Mac App Store:

1. Code sign with Developer ID
2. Enable Hardened Runtime
3. Submit for notarization
4. Staple the ticket

```bash
# Build for release
xcodebuild -scheme DashPane -configuration Release archive

# Notarize
xcrun notarytool submit DashPane.zip --keychain-profile "notarization" --wait

# Staple
xcrun stapler staple DashPane.app
```

## Troubleshooting

### Accessibility Permission Not Working

1. Go to System Settings > Privacy & Security > Accessibility
2. Remove DashPane from the list
3. Re-add DashPane
4. Restart the app

### Command-Tab Not Overriding

Some apps with Secure Input mode (password fields, etc.) may temporarily disable the override. This is expected behavior for security.

### Gestures Not Triggering

- Ensure gestures are enabled in Settings
- Check that cursor is near the screen edge (within 50px by default)
- Gestures only work with trackpad, not mouse scroll wheel

## License

MIT License

## Acknowledgments

Inspired by [Contexts](https://contexts.co/) and [AltTab](https://github.com/lwouis/alt-tab-macos).
