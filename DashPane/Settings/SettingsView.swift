import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ShortcutsSettingsView(settings: settings)
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            SidebarSettingsView(settings: settings)
                .tabItem {
                    Label("Sidebar", systemImage: "sidebar.left")
                }

            GestureSettingsView(settings: settings)
                .tabItem {
                    Label("Gestures", systemImage: "hand.draw")
                }

            LicenseSettingsView()
                .tabItem {
                    Label("License", systemImage: "key")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 480, height: 350)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)

                Picker("Theme", selection: $settings.theme) {
                    ForEach(ThemeOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
            }

            Section("Windows") {
                Toggle("Show windows from all Spaces", isOn: $settings.showWindowsFromAllSpaces)
                Toggle("Show minimized windows", isOn: $settings.showMinimizedWindows)
            }

            Section {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Form {
            Section("Switcher") {
                Toggle("Override Command-Tab", isOn: $settings.enableCommandTabOverride)

                HStack {
                    Text("Quick Search")
                    Spacer()
                    Text("Control + Space")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }

                Toggle("Enable Control-Space", isOn: $settings.enableControlSpace)
            }

            Section {
                Text("Additional shortcuts can be configured in a future update.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Sidebar Settings

struct SidebarSettingsView: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Form {
            Section("Position") {
                Picker("Edge", selection: $settings.sidebarEdge) {
                    ForEach(SidebarEdgeOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Behavior") {
                Toggle("Auto-hide sidebar", isOn: $settings.sidebarAutoHide)

                if settings.sidebarAutoHide {
                    HStack {
                        Text("Hide delay")
                        Slider(value: $settings.sidebarAutoHideDelay, in: 0.1...2.0, step: 0.1)
                        Text("\(settings.sidebarAutoHideDelay, specifier: "%.1f")s")
                            .foregroundColor(.secondary)
                            .frame(width: 40)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Gesture Settings

struct GestureSettingsView: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Form {
            Section {
                Toggle("Enable edge gestures", isOn: $settings.enableGestures)
            }

            if settings.enableGestures {
                Section("Edge Threshold") {
                    HStack {
                        Text("Trigger distance")
                        Slider(value: $settings.gestureEdgeThreshold, in: 20...100, step: 5)
                        Text("\(Int(settings.gestureEdgeThreshold))px")
                            .foregroundColor(.secondary)
                            .frame(width: 50)
                    }
                }

                Section {
                    Text("Scroll with two fingers from the screen edge to show the sidebar.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - License Settings

struct LicenseSettingsView: View {
    @ObservedObject var licenseManager = LicenseManager.shared
    @State private var licenseKeyInput: String = ""
    @State private var showDeactivateConfirm: Bool = false

    var body: some View {
        Form {
            if licenseManager.isLicensed {
                // Licensed state
                Section {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text("DashPane Pro")
                                .font(.headline)
                            Text("Licensed")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }

                Section("License Details") {
                    if let key = licenseManager.licenseKey {
                        LabeledContent("Key") {
                            Text(maskLicenseKey(key))
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    LabeledContent("Machine") {
                        Text(licenseManager.getMachineName())
                    }
                }

                Section {
                    Button("Deactivate License", role: .destructive) {
                        showDeactivateConfirm = true
                    }
                    .alert("Deactivate License?", isPresented: $showDeactivateConfirm) {
                        Button("Cancel", role: .cancel) { }
                        Button("Deactivate", role: .destructive) {
                            licenseManager.deactivateLicense { _, _ in }
                        }
                    } message: {
                        Text("This will remove the license from this Mac.")
                    }
                }
            } else {
                // Unlicensed state
                Section("Activate License") {
                    TextField("DASH-XXXX-XXXX-XXXX", text: $licenseKeyInput)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: licenseKeyInput) { newValue in
                            licenseKeyInput = licenseManager.formatLicenseKey(newValue)
                        }
                        .disabled(licenseManager.isActivating)

                    if let error = licenseManager.activationError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    Button(action: activateLicense) {
                        if licenseManager.isActivating {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text("Activate")
                        }
                    }
                    .disabled(licenseKeyInput.isEmpty || licenseManager.isActivating)
                }

                Section {
                    Button("Purchase License") {
                        if let url = URL(string: "https://dashpane.com/purchase") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func activateLicense() {
        licenseManager.activateLicense(key: licenseKeyInput) { success, _ in
            if success {
                licenseKeyInput = ""
            }
        }
    }

    private func maskLicenseKey(_ key: String) -> String {
        let components = key.split(separator: "-")
        guard components.count == 4 else { return key }
        return "\(components[0])-\(components[1])-****-****"
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("DashPane")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .foregroundColor(.secondary)

            Divider()
                .frame(width: 200)

            Text("A fast window switcher for macOS")
                .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 20) {
                Button("Website") {
                    // Open website
                }

                Button("GitHub") {
                    // Open GitHub
                }
            }
            .buttonStyle(.link)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
