import SwiftUI

struct SidebarView: View {
    @ObservedObject var controller: SidebarController
    var onWindowSelected: (WindowInfo) -> Void

    @State private var expandedApps: Set<String> = []
    @State private var hoveredWindow: WindowInfo?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Window List
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(controller.sortedAppNames(), id: \.self) { appName in
                        AppGroupView(
                            appName: appName,
                            windows: controller.windowsForApp(appName),
                            isExpanded: expandedApps.contains(appName),
                            hoveredWindow: $hoveredWindow,
                            onToggle: {
                                toggleExpanded(appName)
                            },
                            onWindowSelected: onWindowSelected
                        )
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(width: 280)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Windows")
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            Button(action: {
                controller.hide()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func toggleExpanded(_ appName: String) {
        if expandedApps.contains(appName) {
            expandedApps.remove(appName)
        } else {
            expandedApps.insert(appName)
        }
    }
}

// MARK: - App Group View

struct AppGroupView: View {
    let appName: String
    let windows: [WindowInfo]
    let isExpanded: Bool
    @Binding var hoveredWindow: WindowInfo?
    let onToggle: () -> Void
    let onWindowSelected: (WindowInfo) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // App Header
            Button(action: {
                if windows.count == 1 {
                    onWindowSelected(windows[0])
                } else {
                    onToggle()
                }
            }) {
                HStack(spacing: 10) {
                    // App Icon
                    if let appIcon = windows.first?.appIcon {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "app")
                            .frame(width: 24, height: 24)
                    }

                    // App Name
                    Text(appName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    Spacer()

                    // Window count badge
                    if windows.count > 1 {
                        Text("\(windows.count)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)

                        // Expand indicator
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Windows list (when expanded or only one window)
            if isExpanded || windows.count == 1 {
                ForEach(windows, id: \.id) { window in
                    SidebarWindowRowView(
                        window: window,
                        isHovered: hoveredWindow == window,
                        indented: windows.count > 1
                    )
                    .onTapGesture {
                        onWindowSelected(window)
                    }
                    .onHover { isHovered in
                        hoveredWindow = isHovered ? window : nil
                    }
                }
            }
        }
    }
}

// MARK: - Sidebar Window Row

struct SidebarWindowRowView: View {
    let window: WindowInfo
    let isHovered: Bool
    let indented: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Window title
            Text(window.windowTitle.isEmpty ? window.ownerName : window.windowTitle)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.leading, indented ? 46 : 12)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.accentColor.opacity(0.2) : Color.clear)
        )
    }
}

// MARK: - Preview

#Preview {
    SidebarView(
        controller: SidebarController(windowManager: WindowManager()),
        onWindowSelected: { _ in }
    )
    .frame(height: 600)
}
