import SwiftUI

struct PermissionsView: View {
    @ObservedObject var permissionsManager: PermissionsManager
    var onPermissionsGranted: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Permission Required")
                    .font(.title)
                    .fontWeight(.bold)

                Text("DashPane needs Accessibility permission to switch between windows.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)

            Divider()

            // Accessibility Permission
            PermissionStepView(
                icon: "accessibility",
                title: "Accessibility",
                description: "Required to detect windows and switch between them",
                isGranted: permissionsManager.hasAccessibilityPermission,
                isActive: !permissionsManager.hasAccessibilityPermission,
                action: {
                    permissionsManager.requestAccessibilityPermission()
                }
            )
            .padding(.horizontal)

            Spacer()

            // Continue Buttons
            VStack(spacing: 12) {
                if permissionsManager.hasAccessibilityPermission {
                    Button(action: {
                        onPermissionsGranted()
                    }) {
                        Text("Start DashPane")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    // After app rebuild, permission might be granted but check fails
                    // Allow user to continue anyway
                    Button(action: {
                        onPermissionsGranted()
                    }) {
                        Text("I've already granted access - Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Text("Use this if you've already granted permission in System Settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .frame(width: 500, height: 400)
        .onReceive(NotificationCenter.default.publisher(for: .accessibilityPermissionGranted)) { _ in
            permissionsManager.checkAccessibilityPermission()
        }
    }
}

// MARK: - Permission Step View

struct PermissionStepView: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green : (isActive ? Color.accentColor : Color.gray))
                    .frame(width: 40, height: 40)

                Image(systemName: isGranted ? "checkmark" : icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(isActive || isGranted ? .primary : .secondary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Action Button
            if !isGranted && isActive {
                Button("Grant Access") {
                    action()
                }
                .buttonStyle(.bordered)
            } else if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive && !isGranted ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive && !isGranted ? Color.accentColor : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    PermissionsView(
        permissionsManager: PermissionsManager(),
        onPermissionsGranted: {}
    )
}
