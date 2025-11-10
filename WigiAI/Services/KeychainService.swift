//
//  KeychainService.swift
//  WigiAI
//
//  AI Companion Desktop Widget
//

import Foundation
import Security
import OSLog

/// Service for secure storage of API keys in macOS Keychain
///
/// **Security Features:**
/// - API keys never stored in JSON files
/// - Uses macOS Keychain for secure system-level storage
/// - Accessibility: `kSecAttrAccessibleWhenUnlocked` (no password prompts with proper code signing)
/// - Service isolation: Keys scoped to app bundle identifier
/// - Keychain Access Group: App-specific group via entitlements (requires Developer ID signing)
///
/// **Code Signing Requirements:**
/// - Requires valid Apple Developer certificate for password-free access
/// - Entitlements must include `keychain-access-groups` with app identifier
/// - Without proper signing: macOS may prompt for user password (security measure)
///
/// **Migration:**
/// - Automatically migrates API keys from JSON to Keychain on first run
/// - Old JSON keys are cleared after successful migration
///
/// **Important:** This prevents API keys from appearing in:
/// - JSON backups
/// - Debug logs
/// - Git commits
/// - Plain text storage
class KeychainService {
    /// Shared singleton instance
    static let shared = KeychainService()

    /// Keychain service identifier (bundle ID)
    private let service: String

    /// Keychain account name for API key
    private let account = "openai_api_key"

    /// Initializes service with app's bundle identifier as service name
    private init() {
        // Use bundle identifier as service name
        self.service = Bundle.main.bundleIdentifier ?? "com.wigiai.WigiAI"
    }

    // MARK: - Save API Key

    /// Saves API key to macOS Keychain
    ///
    /// - Parameter apiKey: The API key to save securely
    /// - Returns: `true` if saved successfully, `false` on error
    ///
    /// **Behavior:**
    /// - Deletes any existing key first (ensures fresh save)
    /// - Uses `kSecAttrAccessibleWhenUnlocked` to prevent password prompts
    /// - Logs success/failure for debugging
    @discardableResult
    func saveAPIKey(_ apiKey: String) -> Bool {
        // Delete existing key first (if any)
        deleteAPIKey()

        guard let data = apiKey.data(using: .utf8) else {
            LoggerService.storage.error("❌ Keychain: Failed to encode API key")
            return false
        }

        // CRITICAL: Use kSecAttrAccessibleWhenUnlocked to prevent password prompts
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            LoggerService.storage.info("✅ Keychain: API key saved successfully")
            return true
        } else {
            LoggerService.storage.error("❌ Keychain: Failed to save API key (status: \(status))")
            return false
        }
    }

    // MARK: - Load API Key

    /// Loads API key from macOS Keychain
    ///
    /// - Returns: API key string if found, `nil` if not found or on error
    ///
    /// **Error Handling:**
    /// - Returns `nil` if key doesn't exist (normal for first run)
    /// - Returns `nil` if decoding fails
    /// - Logs detailed error info for debugging
    func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            if let data = result as? Data,
               let apiKey = String(data: data, encoding: .utf8) {
                LoggerService.storage.debug("✅ Keychain: API key loaded successfully")
                return apiKey
            } else {
                LoggerService.storage.error("❌ Keychain: Failed to decode API key data")
                return nil
            }
        } else if status == errSecItemNotFound {
            LoggerService.storage.debug("ℹ️ Keychain: No API key found")
            return nil
        } else {
            LoggerService.storage.error("❌ Keychain: Failed to load API key (status: \(status))")
            return nil
        }
    }

    // MARK: - Delete API Key

    /// Deletes API key from macOS Keychain
    ///
    /// - Returns: `true` if deleted or didn't exist, `false` on error
    ///
    /// **Note:** Returns `true` if key doesn't exist (not considered an error)
    @discardableResult
    func deleteAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess {
            LoggerService.storage.info("✅ Keychain: API key deleted successfully")
            return true
        } else if status == errSecItemNotFound {
            // Not an error - key didn't exist
            LoggerService.storage.debug("ℹ️ Keychain: No API key to delete")
            return true
        } else {
            LoggerService.storage.error("❌ Keychain: Failed to delete API key (status: \(status))")
            return false
        }
    }
}
