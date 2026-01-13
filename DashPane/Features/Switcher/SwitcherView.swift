import SwiftUI

struct SwitcherView: View {
    @ObservedObject var controller: SwitcherController
    @State private var showSearchBar = false

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar (only visible in search mode or when typing)
            if controller.isSearchMode || !controller.searchText.isEmpty {
                SearchBarView(
                    text: $controller.searchText,
                    onSubmit: {
                        controller.activateSelectedAndHide()
                    },
                    onArrowUp: {
                        controller.selectPrevious()
                    },
                    onArrowDown: {
                        controller.selectNext()
                    },
                    onEscape: {
                        controller.hide()
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }

            // Window List
            if controller.filteredResults.isEmpty {
                emptyState
            } else {
                windowList
            }
        }
        .frame(width: 700, height: max(120, min(CGFloat(controller.filteredResults.count) * 32 + (controller.isSearchMode ? 80 : 24), 500)))
        .background(Color(NSColor.textBackgroundColor))  // Light background
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
    }

    // MARK: - Window List

    private var windowList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(controller.displayItems.enumerated()), id: \.element.id) { index, item in
                        switch item.type {
                        case .sectionHeader(let title):
                            SectionHeaderRow(title: title)
                                .id(item.id)

                        case .windowItem(let window, let shortcut):
                            WindowRow(
                                window: window,
                                shortcut: shortcut,
                                isSelected: index == controller.selectedIndex,
                                showShortcut: !controller.isSearchMode,
                                onTap: {
                                    controller.selectIndex(index)
                                    controller.activateSelectedAndHide()
                                }
                            )
                            .id(item.id)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: controller.selectedIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.1)) {
                    if let itemId = controller.displayItems[safe: newIndex]?.id {
                        proxy.scrollTo(itemId, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No windows found")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 60)
    }
}

// MARK: - Section Header Row

struct SectionHeaderRow: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }
}

// MARK: - Window Row

struct WindowRow: View {
    let window: WindowInfo
    let shortcut: String
    let isSelected: Bool
    let showShortcut: Bool
    let onTap: () -> Void

    var body: some View {
        ContextsStyleRow(
            window: window,
            shortcutKey: shortcut,
            isSelected: isSelected,
            showShortcut: showShortcut
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Contexts-Style Row

struct ContextsStyleRow: View {
    let window: WindowInfo
    let shortcutKey: String
    let isSelected: Bool
    var showShortcut: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            // Shortcut key (wider column, left-aligned) - only in non-search mode
            if showShortcut {
                Text(shortcutKey)
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : Color(NSColor.tertiaryLabelColor))
                    .frame(width: 36, alignment: .leading)
                    .padding(.leading, 16)
            } else {
                Spacer().frame(width: 16)
            }

            Spacer()

            // App name (right-aligned before icon)
            Text(window.ownerName)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)

            // App Icon
            Group {
                if let appIcon = window.appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 14))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                        .frame(width: 18, height: 18)
                }
            }
            .padding(.horizontal, 12)

            // Window title (shows tab name, document name, etc.)
            Text(windowTitleDisplay)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .white.opacity(0.9) : Color(NSColor.secondaryLabelColor))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer().frame(width: 16)
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
    }

    /// Format the window title for display
    private var windowTitleDisplay: String {
        let title = window.windowTitle

        // If title is empty, show app name
        if title.isEmpty {
            return window.ownerName
        }

        // Show the window title as-is (tab name, file name, etc.)
        return title
    }
}

// MARK: - Search Bar

struct SearchBarView: View {
    @Binding var text: String
    var onSubmit: () -> Void
    var onArrowUp: () -> Void
    var onArrowDown: () -> Void
    var onEscape: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 14))

            KeyHandlingTextField(
                text: $text,
                placeholder: "Search windows...",
                onSubmit: onSubmit,
                onArrowUp: onArrowUp,
                onArrowDown: onArrowDown,
                onEscape: onEscape
            )
            .font(.system(size: 14))

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

// MARK: - Key Handling TextField

struct KeyHandlingTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    var onArrowUp: () -> Void
    var onArrowDown: () -> Void
    var onEscape: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let textField = KeyHandlingNSTextField()
        textField.delegate = context.coordinator
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.font = NSFont.systemFont(ofSize: 14)
        textField.onArrowUp = onArrowUp
        textField.onArrowDown = onArrowDown
        textField.onEscape = onEscape

        // Make it first responder with a slight delay to ensure window is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if let window = textField.window {
                window.makeFirstResponder(textField)
            }
        }

        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if let keyField = nsView as? KeyHandlingNSTextField {
            keyField.onArrowUp = onArrowUp
            keyField.onArrowDown = onArrowDown
            keyField.onEscape = onEscape
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: KeyHandlingTextField

        init(_ parent: KeyHandlingTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}

class KeyHandlingNSTextField: NSTextField {
    var onArrowUp: (() -> Void)?
    var onArrowDown: (() -> Void)?
    var onEscape: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126: // Up arrow
            onArrowUp?()
        case 125: // Down arrow
            onArrowDown?()
        case 53: // Escape
            onEscape?()
        default:
            super.keyDown(with: event)
        }
    }
}

// MARK: - Visual Effect View

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Preview

#Preview {
    SwitcherView(controller: SwitcherController(windowManager: WindowManager()))
        .frame(width: 700, height: 400)
}
