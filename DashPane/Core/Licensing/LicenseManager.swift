import Foundation
import IOKit
import Security

/// Manages license activation, validation, and storage for DashPane
class LicenseManager: ObservableObject {

    // MARK: - Singleton

    static let shared = LicenseManager()

    // MARK: - Published Properties

    @Published var isLicensed: Bool = false
    @Published var licenseKey: String?
    @Published var activationError: String?
    @Published var isActivating: Bool = false

    // MARK: - Configuration

    /// Base URL for the licensing server
    /// Change this to your production server URL when deploying
    #if DEBUG
    private let serverBaseURL = "http://localhost:3000"
    #else
    private let serverBaseURL = "https://your-licensing-server.com"  // TODO: Update with your server URL
    #endif

    // MARK: - Keychain Keys

    private let keychainService = "com.dashpane.license"
    private let keychainAccountKey = "license_key"
    private let keychainAccountHardwareId = "hardware_id"

    // MARK: - Initialization

    private init() {
        loadStoredLicense()
    }

    // MARK: - Hardware ID

    /// Gets the unique hardware UUID for this Mac
    func getHardwareUUID() -> String? {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )

        guard platformExpert > 0 else {
            NSLog("LicenseManager: Failed to get platform expert service")
            return nil
        }

        defer { IOObjectRelease(platformExpert) }

        guard let uuidData = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        ) else {
            NSLog("LicenseManager: Failed to get UUID property")
            return nil
        }

        let uuid = uuidData.takeRetainedValue() as? String
        return uuid
    }

    /// Gets the Mac's serial number
    func getMacSerialNumber() -> String? {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )

        guard platformExpert > 0 else { return nil }
        defer { IOObjectRelease(platformExpert) }

        guard let serialData = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformSerialNumberKey as CFString,
            kCFAllocatorDefault,
            0
        ) else { return nil }

        return serialData.takeRetainedValue() as? String
    }

    /// Gets the machine name (e.g., "John's MacBook Pro")
    func getMachineName() -> String {
        return Host.current().localizedName ?? "Mac"
    }

    // MARK: - License Storage (Keychain)

    private func saveToKeychain(key: String, value: String) -> Bool {
        let data = value.data(using: .utf8)!

        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - License Operations

    /// Loads stored license from Keychain and validates it
    func loadStoredLicense() {
        guard let storedKey = loadFromKeychain(key: keychainAccountKey),
              let storedHardwareId = loadFromKeychain(key: keychainAccountHardwareId) else {
            NSLog("LicenseManager: No stored license found")
            isLicensed = false
            return
        }

        // Verify hardware ID matches current machine
        guard let currentHardwareId = getHardwareUUID(),
              storedHardwareId == currentHardwareId else {
            NSLog("LicenseManager: Hardware ID mismatch, clearing license")
            clearStoredLicense()
            return
        }

        licenseKey = storedKey

        // Validate with server in background
        validateLicenseAsync(key: storedKey, hardwareId: currentHardwareId) { [weak self] isValid in
            DispatchQueue.main.async {
                self?.isLicensed = isValid
                if !isValid {
                    NSLog("LicenseManager: Server validation failed")
                }
            }
        }

        // Optimistically set as licensed (offline mode support)
        isLicensed = true
    }

    /// Activates a license key
    func activateLicense(key: String, completion: @escaping (Bool, String?) -> Void) {
        guard !key.isEmpty else {
            completion(false, "Please enter a license key")
            return
        }

        guard let hardwareId = getHardwareUUID() else {
            completion(false, "Failed to get hardware ID")
            return
        }

        let machineName = getMachineName()

        isActivating = true
        activationError = nil

        let url = URL(string: "\(serverBaseURL)/api/license/activate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "license_key": key.uppercased().trimmingCharacters(in: .whitespacesAndNewlines),
            "hardware_id": hardwareId,
            "machine_name": machineName
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            isActivating = false
            completion(false, "Failed to encode request")
            return
        }

        NSLog("LicenseManager: Activating license...")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isActivating = false

                if let error = error {
                    NSLog("LicenseManager: Network error - \(error.localizedDescription)")
                    self?.activationError = "Network error: \(error.localizedDescription)"
                    completion(false, self?.activationError)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.activationError = "Invalid server response"
                    completion(false, self?.activationError)
                    return
                }

                guard let data = data else {
                    self?.activationError = "No response data"
                    completion(false, self?.activationError)
                    return
                }

                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                    if httpResponse.statusCode == 200, let success = json?["success"] as? Bool, success {
                        // Activation successful
                        let normalizedKey = key.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

                        // Save to keychain
                        _ = self?.saveToKeychain(key: self?.keychainAccountKey ?? "", value: normalizedKey)
                        _ = self?.saveToKeychain(key: self?.keychainAccountHardwareId ?? "", value: hardwareId)

                        self?.licenseKey = normalizedKey
                        self?.isLicensed = true
                        self?.activationError = nil

                        NSLog("LicenseManager: Activation successful")
                        completion(true, nil)
                    } else {
                        // Activation failed
                        let errorMessage = json?["error"] as? String ?? "Activation failed"
                        self?.activationError = errorMessage
                        NSLog("LicenseManager: Activation failed - \(errorMessage)")
                        completion(false, errorMessage)
                    }
                } catch {
                    self?.activationError = "Failed to parse response"
                    completion(false, self?.activationError)
                }
            }
        }.resume()
    }

    /// Validates license with server
    private func validateLicenseAsync(key: String, hardwareId: String, completion: @escaping (Bool) -> Void) {
        let url = URL(string: "\(serverBaseURL)/api/license/validate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "license_key": key,
            "hardware_id": hardwareId
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(false)
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let valid = json["valid"] as? Bool else {
                // Network error - allow offline usage if previously activated
                completion(true)
                return
            }

            completion(valid)
        }.resume()
    }

    /// Deactivates the current license
    func deactivateLicense(completion: @escaping (Bool, String?) -> Void) {
        guard let key = licenseKey,
              let hardwareId = getHardwareUUID() else {
            clearStoredLicense()
            completion(true, nil)
            return
        }

        let url = URL(string: "\(serverBaseURL)/api/license/deactivate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "license_key": key,
            "hardware_id": hardwareId
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            clearStoredLicense()
            completion(true, nil)
            return
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                // Clear local license regardless of server response
                self?.clearStoredLicense()
                completion(true, nil)
            }
        }.resume()
    }

    /// Clears stored license data
    private func clearStoredLicense() {
        deleteFromKeychain(key: keychainAccountKey)
        deleteFromKeychain(key: keychainAccountHardwareId)
        licenseKey = nil
        isLicensed = false
    }

    // MARK: - License Key Formatting

    /// Formats a license key with dashes (DASH-XXXX-XXXX-XXXX)
    func formatLicenseKey(_ input: String) -> String {
        let cleaned = input.uppercased().replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)

        var result = ""
        var index = 0

        // Add prefix if not present
        if cleaned.hasPrefix("DASH") {
            result = "DASH"
            index = 4
        }

        while index < cleaned.count {
            if !result.isEmpty && !result.hasSuffix("-") {
                result += "-"
            }

            let start = cleaned.index(cleaned.startIndex, offsetBy: index)
            let end = cleaned.index(start, offsetBy: min(4, cleaned.count - index))
            result += String(cleaned[start..<end])
            index += 4
        }

        return result
    }
}
