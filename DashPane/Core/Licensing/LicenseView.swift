import SwiftUI

/// View for license activation and management
struct LicenseView: View {
    @ObservedObject var licenseManager = LicenseManager.shared
    @State private var licenseKeyInput: String = ""
    @State private var showSuccessMessage: Bool = false
    @State private var showDeactivateConfirm: Bool = false

    var onLicenseActivated: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 24) {
                    if licenseManager.isLicensed {
                        licensedView
                    } else {
                        activationView
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 480, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 24))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("License")
                    .font(.headline)
                Text(licenseManager.isLicensed ? "Licensed" : "Activate your license")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if licenseManager.isLicensed {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Activation View

    private var activationView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter your license key")
                    .font(.headline)

                Text("You received your license key via email after purchase. Enter it below to activate DashPane.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // License key input
            VStack(alignment: .leading, spacing: 8) {
                TextField("DASH-XXXX-XXXX-XXXX", text: $licenseKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: licenseKeyInput) { newValue in
                        licenseKeyInput = licenseManager.formatLicenseKey(newValue)
                    }
                    .disabled(licenseManager.isActivating)

                if let error = licenseManager.activationError {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                    }
                    .font(.caption)
                }
            }

            // Activate button
            Button(action: activateLicense) {
                HStack {
                    if licenseManager.isActivating {
                        ProgressView()
                            .scaleEffect(0.7)
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                    Text(licenseManager.isActivating ? "Activating..." : "Activate License")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(licenseKeyInput.isEmpty || licenseManager.isActivating)

            Divider()

            // Purchase link
            VStack(alignment: .leading, spacing: 8) {
                Text("Don't have a license?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button(action: openPurchasePage) {
                    HStack {
                        Image(systemName: "cart")
                        Text("Purchase DashPane")
                    }
                }
                .buttonStyle(.link)
            }

            // Machine info
            VStack(alignment: .leading, spacing: 4) {
                Text("Machine Information")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Machine: \(licenseManager.getMachineName())")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let uuid = licenseManager.getHardwareUUID() {
                    Text("ID: \(String(uuid.prefix(8)))...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - Licensed View

    private var licensedView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Success message
            if showSuccessMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("License activated successfully!")
                        .foregroundColor(.green)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }

            // License info
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.title)
                    VStack(alignment: .leading) {
                        Text("DashPane Pro")
                            .font(.headline)
                        Text("Licensed")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // License details
                VStack(alignment: .leading, spacing: 8) {
                    if let key = licenseManager.licenseKey {
                        HStack {
                            Text("License Key:")
                                .foregroundColor(.secondary)
                            Text(maskLicenseKey(key))
                                .font(.system(.body, design: .monospaced))
                        }
                    }

                    HStack {
                        Text("Machine:")
                            .foregroundColor(.secondary)
                        Text(licenseManager.getMachineName())
                    }
                }
                .font(.subheadline)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Spacer()

            // Deactivate button
            Button(action: { showDeactivateConfirm = true }) {
                Text("Deactivate License")
            }
            .buttonStyle(.link)
            .foregroundColor(.red)
            .alert("Deactivate License?", isPresented: $showDeactivateConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Deactivate", role: .destructive) {
                    deactivateLicense()
                }
            } message: {
                Text("This will remove the license from this Mac. You can reactivate it later.")
            }
        }
    }

    // MARK: - Actions

    private func activateLicense() {
        licenseManager.activateLicense(key: licenseKeyInput) { success, error in
            if success {
                showSuccessMessage = true
                onLicenseActivated?()

                // Hide success message after a few seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showSuccessMessage = false
                }
            }
        }
    }

    private func deactivateLicense() {
        licenseManager.deactivateLicense { success, error in
            licenseKeyInput = ""
        }
    }

    private func openPurchasePage() {
        // TODO: Update with your purchase page URL
        if let url = URL(string: "https://dashpane.com/purchase") {
            NSWorkspace.shared.open(url)
        }
    }

    private func maskLicenseKey(_ key: String) -> String {
        // Show format: DASH-XXXX-****-****
        let components = key.split(separator: "-")
        guard components.count == 4 else { return key }
        return "\(components[0])-\(components[1])-****-****"
    }
}

/// Standalone license activation window for first-time setup
struct LicenseActivationWindow: View {
    @ObservedObject var licenseManager = LicenseManager.shared
    @State private var licenseKeyInput: String = ""

    var onActivated: () -> Void
    var onSkip: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // App icon and title
            VStack(spacing: 16) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)

                Text("Welcome to DashPane")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text("Enter your license key to get started")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 32)

            // License input
            VStack(spacing: 16) {
                TextField("DASH-XXXX-XXXX-XXXX", text: $licenseKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 18, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .onChange(of: licenseKeyInput) { newValue in
                        licenseKeyInput = licenseManager.formatLicenseKey(newValue)
                    }
                    .disabled(licenseManager.isActivating)

                if let error = licenseManager.activationError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button(action: activate) {
                    HStack {
                        if licenseManager.isActivating {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text(licenseManager.isActivating ? "Activating..." : "Activate")
                    }
                    .frame(width: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(licenseKeyInput.isEmpty || licenseManager.isActivating)
            }
            .padding(.horizontal, 40)

            Spacer()

            // Footer
            VStack(spacing: 12) {
                Button("Purchase License") {
                    if let url = URL(string: "https://dashpane.com/purchase") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)

                if let onSkip = onSkip {
                    Button("Continue in Trial Mode") {
                        onSkip()
                    }
                    .buttonStyle(.link)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 24)
        }
        .frame(width: 500, height: 450)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func activate() {
        licenseManager.activateLicense(key: licenseKeyInput) { success, error in
            if success {
                onActivated()
            }
        }
    }
}

#Preview {
    LicenseView()
}
