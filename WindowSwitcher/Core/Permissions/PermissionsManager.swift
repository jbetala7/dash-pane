import Cocoa
import ApplicationServices

class PermissionsManager: ObservableObject {

    // MARK: - Published Properties

    @Published var hasAccessibilityPermission = false

    // MARK: - Private Properties

    private var permissionMonitorTimer: Timer?

    // MARK: - Accessibility Permission

    func checkAccessibilityPermission() -> Bool {
        let trusted = AXIsProcessTrusted()
        hasAccessibilityPermission = trusted
        return trusted
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        // Start polling for permission changes
        startAccessibilityPermissionPolling()
    }

    private func startAccessibilityPermissionPolling() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            if self.checkAccessibilityPermission() {
                timer.invalidate()
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .accessibilityPermissionGranted,
                        object: nil
                    )
                }
            }
        }
    }

    /// Start continuous monitoring for permission changes (including revocation)
    func startContinuousPermissionMonitoring() {
        // Stop any existing timer
        permissionMonitorTimer?.invalidate()

        permissionMonitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let currentStatus = AXIsProcessTrusted()
            let previousStatus = self.hasAccessibilityPermission

            if currentStatus != previousStatus {
                self.hasAccessibilityPermission = currentStatus

                DispatchQueue.main.async {
                    if currentStatus {
                        NotificationCenter.default.post(
                            name: .accessibilityPermissionGranted,
                            object: nil
                        )
                    } else {
                        // Permission was revoked!
                        NotificationCenter.default.post(
                            name: .accessibilityPermissionRevoked,
                            object: nil
                        )
                    }
                }
            }
        }
    }

    func stopContinuousPermissionMonitoring() {
        permissionMonitorTimer?.invalidate()
        permissionMonitorTimer = nil
    }

    // MARK: - Open System Preferences

    func openAccessibilityPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

}

// MARK: - Notification Names

extension Notification.Name {
    static let accessibilityPermissionGranted = Notification.Name("accessibilityPermissionGranted")
    static let accessibilityPermissionRevoked = Notification.Name("accessibilityPermissionRevoked")
}
