//
//  StorageService.swift
//  WigiAI
//
//  AI Companion Desktop Widget
//

import Foundation
import OSLog

class StorageService {
    static let shared = StorageService()

    private let settingsFileName = "app_settings.json"
    private let charactersDirectoryName = "characters"

    /// Custom directory for testing. When nil, uses Application Support directory.
    private let customDirectory: URL?

    private var appSupportDirectory: URL {
        // If custom directory is set (for testing), use it
        if let customDirectory = customDirectory {
            // Create directory if needed
            try? FileManager.default.createDirectory(at: customDirectory, withIntermediateDirectories: true)
            return customDirectory
        }

        // Production path: Application Support
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Fallback to temporary directory if Application Support is unavailable
            LoggerService.storage.warning("⚠️ Application Support directory not found, using temporary directory")
            let tempDir = FileManager.default.temporaryDirectory
            let appDirectory = tempDir.appendingPathComponent("WigiAI", isDirectory: true)

            // Create directory in temp location with explicit error handling
            do {
                try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
                LoggerService.storage.info("✅ Created WigiAI directory in temporary location")
            } catch {
                LoggerService.storage.error("❌ CRITICAL: Failed to create directory in temp location: \(error.localizedDescription)")
                LoggerService.storage.error("   App may not be able to save data. Check filesystem permissions.")
            }

            return appDirectory
        }

        let appDirectory = appSupport.appendingPathComponent("WigiAI", isDirectory: true)

        // Create directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        } catch {
            LoggerService.storage.error("❌ Failed to create WigiAI directory: \(error.localizedDescription)")
            LoggerService.storage.error("   Path: \(appDirectory.path)")

            // Log specific error types to help debugging
            if let nsError = error as NSError? {
                switch nsError.code {
                case NSFileWriteNoPermissionError:
                    LoggerService.storage.error("   Reason: No permission to create directory")
                case NSFileWriteVolumeReadOnlyError:
                    LoggerService.storage.error("   Reason: Volume is read-only")
                case NSFileWriteOutOfSpaceError:
                    LoggerService.storage.error("   Reason: Disk is full")
                default:
                    LoggerService.storage.error("   Error code: \(nsError.code)")
                }
            }
        }

        return appDirectory
    }

    private var settingsURL: URL {
        appSupportDirectory.appendingPathComponent(settingsFileName)
    }

    private var charactersDirectory: URL {
        let dir = appSupportDirectory.appendingPathComponent(charactersDirectoryName, isDirectory: true)

        // Create characters directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            LoggerService.storage.error("❌ Failed to create characters directory: \(error.localizedDescription)")
            LoggerService.storage.error("   Path: \(dir.path)")

            // Log specific error details for debugging
            if let nsError = error as NSError? {
                LoggerService.storage.error("   Error code: \(nsError.code), domain: \(nsError.domain)")
            }
        }

        return dir
    }

    private var backupDirectory: URL {
        let dir = appSupportDirectory.appendingPathComponent("backups", isDirectory: true)

        // Create backup directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            LoggerService.storage.error("❌ Failed to create backup directory: \(error.localizedDescription)")
            LoggerService.storage.error("   Path: \(dir.path)")
            LoggerService.storage.error("   Backups will not be available until this is resolved")

            // Log specific error details for debugging
            if let nsError = error as NSError? {
                LoggerService.storage.error("   Error code: \(nsError.code), domain: \(nsError.domain)")
            }
        }

        return dir
    }

    private init() {
        self.customDirectory = nil
    }

    /// Initialize with custom directory (for testing)
    init(customDirectory: URL) {
        self.customDirectory = customDirectory
    }

    // MARK: - Load Settings

    func loadSettings() -> AppSettings {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            LoggerService.app.debug("ℹ️ Settings file not found, creating default settings")
            let defaultSettings = AppSettings.defaultSettings
            saveSettings(defaultSettings)
            return defaultSettings
        }

        do {
            let data = try Data(contentsOf: settingsURL)

            // Validate data before decoding (corruption detection)
            if !validateData(data, as: AppSettings.self) {
                LoggerService.storage.error("❌ Settings file corrupted, attempting recovery...")
                if let recovered = recoverSettingsFromBackup() {
                    LoggerService.storage.info("✅ Settings recovered from backup")
                    return recovered
                }
                LoggerService.storage.error("❌ Recovery failed, using default settings")
                return AppSettings.defaultSettings
            }

            var settings = try JSONDecoder().decode(AppSettings.self, from: data)
            LoggerService.app.debug("📂 Settings loaded successfully from: \(self.settingsURL.path)")

            // MIGRATION: Move API key from JSON to Keychain (one-time migration)
            if !settings.globalAPIConfig.apiKey.isEmpty {
                LoggerService.storage.info("🔄 Migrating API key from JSON to Keychain...")
                KeychainService.shared.saveAPIKey(settings.globalAPIConfig.apiKey)
                settings.globalAPIConfig.apiKey = ""  // Clear from JSON
                saveSettings(settings)  // Save without the key
                LoggerService.storage.info("✅ API key migration complete")
            }

            // MIGRATION: Detect old format and migrate to multi-file structure
            // Old format has "characters" array in JSON, new format only has "characterIds"
            let oldData = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let oldCharacters = oldData?["characters"] as? [[String: Any]], !oldCharacters.isEmpty {
                LoggerService.storage.info("🔄 Migrating from single-file to multi-file storage...")
                migrateToMultiFile(from: data, settings: &settings)
                LoggerService.storage.info("✅ Migration to multi-file storage complete")
            }

            return settings
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
                // File doesn't exist yet - this is normal for first run
                LoggerService.app.debug("ℹ️ Settings file not found (first run)")
            } else if error.domain == NSCocoaErrorDomain {
                switch error.code {
                case NSFileReadNoPermissionError:
                    LoggerService.storage.warning("⚠️ No permission to read settings file")
                case NSFileReadCorruptFileError:
                    LoggerService.storage.warning("⚠️ Settings file is corrupted")
                default:
                    LoggerService.storage.warning("⚠️ Failed to load settings: \(error.localizedDescription)")
                }
            } else if error is DecodingError {
                LoggerService.storage.warning("⚠️ Failed to decode settings JSON: \(error.localizedDescription)")
            } else {
                LoggerService.storage.warning("⚠️ Error loading settings: \(error.localizedDescription)")
            }

            LoggerService.app.debug("ℹ️ Using default settings as fallback")
            return AppSettings.defaultSettings
        } catch {
            LoggerService.storage.warning("⚠️ Unexpected error loading settings: \(error.localizedDescription)")
            return AppSettings.defaultSettings
        }
    }

    // MARK: - Save Settings

    /// Saves settings synchronously (use for small operations or when blocking is acceptable)
    @discardableResult
    func saveSettings(_ settings: AppSettings) -> Result<Void, Error> {
        // Step 1: Create backup of existing file before overwriting
        if FileManager.default.fileExists(atPath: settingsURL.path) {
            _ = backupSettings()  // Best effort backup, continue even if it fails
        }

        // Step 2: CRITICAL: Always clear API key before saving to JSON
        var settingsToSave = settings
        settingsToSave.globalAPIConfig.apiKey = ""

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(settingsToSave)

            // Step 3: Validate data before writing (corruption detection)
            guard validateData(data, as: AppSettings.self) else {
                throw NSError(domain: "StorageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Settings validation failed - data corrupted"])
            }

            // Step 4: Write to disk atomically
            try data.write(to: settingsURL, options: .atomic)
            LoggerService.storage.info("💾 Settings saved successfully to: \(self.settingsURL.path)")
            return .success(())
        } catch let error as NSError {
            let errorMessage: String
            switch error.domain {
            case NSCocoaErrorDomain:
                switch error.code {
                case NSFileWriteOutOfSpaceError:
                    errorMessage = "Disk full - cannot save settings"
                    LoggerService.storage.error("❌ \(errorMessage)")
                case NSFileWriteNoPermissionError:
                    errorMessage = "No permission to write settings file"
                    LoggerService.storage.error("❌ \(errorMessage)")
                case NSFileWriteVolumeReadOnlyError:
                    errorMessage = "Volume is read-only - cannot save settings"
                    LoggerService.storage.error("❌ \(errorMessage)")
                default:
                    errorMessage = "File write error: \(error.localizedDescription)"
                    LoggerService.storage.error("❌ \(errorMessage)")
                }
            default:
                errorMessage = "Unexpected error: \(error.localizedDescription)"
                LoggerService.storage.error("❌ \(errorMessage)")
            }
            return .failure(NSError(domain: "StorageService", code: error.code, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
        } catch {
            LoggerService.storage.error("❌ Error saving settings: \(error.localizedDescription)")
            return .failure(error)
        }
    }

    /// Saves settings asynchronously on background queue (prevents UI blocking)
    /// - Parameter settings: The settings to save
    /// - Returns: Result of the save operation
    @discardableResult
    func saveSettingsAsync(_ settings: AppSettings) async -> Result<Void, Error> {
        // Perform the save on a background queue
        return await Task.detached(priority: .background) { [weak self] in
            guard let self = self else {
                return .failure(NSError(domain: "StorageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Storage service deallocated"]))
            }
            return self.saveSettings(settings)
        }.value
    }

    // MARK: - Backup & Recovery

    /// Creates a backup of settings file
    @discardableResult
    private func backupSettings() -> Result<Void, Error> {
        let backupURL = backupDirectory.appendingPathComponent("app_settings.backup.json")

        do {
            if FileManager.default.fileExists(atPath: settingsURL.path) {
                // Remove old backup if it exists
                if FileManager.default.fileExists(atPath: backupURL.path) {
                    try FileManager.default.removeItem(at: backupURL)
                }
                // Create new backup
                try FileManager.default.copyItem(at: settingsURL, to: backupURL)
                LoggerService.storage.debug("💾 Settings backup created")
                return .success(())
            }
            return .success(()) // No file to backup yet
        } catch {
            LoggerService.storage.warning("⚠️ Failed to create settings backup: \(error.localizedDescription)")
            return .failure(error)
        }
    }

    /// Attempts to recover settings from backup
    private func recoverSettingsFromBackup() -> AppSettings? {
        let backupURL = backupDirectory.appendingPathComponent("app_settings.backup.json")

        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            LoggerService.storage.warning("⚠️ No backup file found for recovery")
            return nil
        }

        do {
            let data = try Data(contentsOf: backupURL)
            let settings = try JSONDecoder().decode(AppSettings.self, from: data)
            LoggerService.storage.info("✅ Settings recovered from backup")
            return settings
        } catch {
            LoggerService.storage.error("❌ Failed to recover settings from backup: \(error.localizedDescription)")
            return nil
        }
    }

    /// Validates that data is valid JSON and can be decoded
    private func validateData<T: Decodable>(_ data: Data, as type: T.Type) -> Bool {
        do {
            _ = try JSONDecoder().decode(type, from: data)
            return true
        } catch {
            LoggerService.storage.error("❌ Data validation failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Creates a backup of a character file
    @discardableResult
    private func backupCharacter(id: UUID) -> Result<Void, Error> {
        let characterURL = charactersDirectory.appendingPathComponent("\(id.uuidString).json")
        let backupURL = backupDirectory.appendingPathComponent("\(id.uuidString).backup.json")

        do {
            if FileManager.default.fileExists(atPath: characterURL.path) {
                // Remove old backup if it exists
                if FileManager.default.fileExists(atPath: backupURL.path) {
                    try FileManager.default.removeItem(at: backupURL)
                }
                // Create new backup
                try FileManager.default.copyItem(at: characterURL, to: backupURL)
                LoggerService.storage.debug("💾 Character backup created for \(id)")
                return .success(())
            }
            return .success(()) // No file to backup yet
        } catch {
            LoggerService.storage.warning("⚠️ Failed to create character backup: \(error.localizedDescription)")
            return .failure(error)
        }
    }

    /// Attempts to recover a character from backup
    private func recoverCharacterFromBackup(id: UUID) -> Character? {
        let backupURL = backupDirectory.appendingPathComponent("\(id.uuidString).backup.json")

        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            LoggerService.storage.warning("⚠️ No backup file found for character \(id)")
            return nil
        }

        do {
            let data = try Data(contentsOf: backupURL)
            let character = try JSONDecoder().decode(Character.self, from: data)
            LoggerService.storage.info("✅ Character recovered from backup: \(character.name)")
            return character
        } catch {
            LoggerService.storage.error("❌ Failed to recover character from backup: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Character Management

    /// Load all characters from individual files
    func loadCharacters(for settings: AppSettings) -> [Character] {
        var characters: [Character] = []

        for characterId in settings.characterIds {
            if let character = loadCharacter(id: characterId) {
                characters.append(character)
            } else {
                LoggerService.storage.warning("⚠️ Failed to load character with ID: \(characterId)")
            }
        }

        LoggerService.app.debug("📂 Loaded \(characters.count) characters from individual files")
        for character in characters {
            LoggerService.app.debug("   - \(character.name): \(character.chatHistory.count) messages")
        }

        return characters
    }

    /// Load a single character by ID
    func loadCharacter(id: UUID) -> Character? {
        let characterURL = charactersDirectory.appendingPathComponent("\(id.uuidString).json")

        guard FileManager.default.fileExists(atPath: characterURL.path) else {
            LoggerService.storage.warning("⚠️ Character file not found: \(characterURL.path)")
            return nil
        }

        do {
            let data = try Data(contentsOf: characterURL)

            // Validate data before decoding (corruption detection)
            if !validateData(data, as: Character.self) {
                LoggerService.storage.error("❌ Character file corrupted (\(id)), attempting recovery...")
                if let recovered = recoverCharacterFromBackup(id: id) {
                    LoggerService.storage.info("✅ Character recovered from backup")
                    return recovered
                }
                LoggerService.storage.error("❌ Recovery failed for character \(id)")
                return nil
            }

            let character = try JSONDecoder().decode(Character.self, from: data)
            return character
        } catch {
            LoggerService.storage.error("❌ Failed to load character \(id): \(error.localizedDescription)")
            // Attempt recovery from backup
            if let recovered = recoverCharacterFromBackup(id: id) {
                LoggerService.storage.info("✅ Character recovered from backup after load error")
                return recovered
            }
            return nil
        }
    }

    /// Save a single character to its own file (synchronous)
    @discardableResult
    func saveCharacter(_ character: Character) -> Result<Void, Error> {
        let characterURL = charactersDirectory.appendingPathComponent("\(character.id.uuidString).json")

        // Step 1: Create backup of existing file before overwriting
        if FileManager.default.fileExists(atPath: characterURL.path) {
            _ = backupCharacter(id: character.id)  // Best effort backup
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(character)

            // Step 2: Validate data before writing (corruption detection)
            guard validateData(data, as: Character.self) else {
                throw NSError(domain: "StorageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Character validation failed - data corrupted"])
            }

            // Step 3: Write to disk atomically
            try data.write(to: characterURL, options: .atomic)
            LoggerService.storage.info("💾 Character saved: \(character.name) (\(character.chatHistory.count) messages)")
            return .success(())
        } catch {
            LoggerService.storage.error("❌ Failed to save character \(character.name): \(error.localizedDescription)")
            return .failure(error)
        }
    }

    /// Save a single character to its own file (asynchronous, prevents UI blocking)
    /// - Parameter character: The character to save
    /// - Returns: Result of the save operation
    @discardableResult
    func saveCharacterAsync(_ character: Character) async -> Result<Void, Error> {
        // Perform the save on a background queue
        return await Task.detached(priority: .background) { [weak self] in
            guard let self = self else {
                return .failure(NSError(domain: "StorageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Storage service deallocated"]))
            }
            return self.saveCharacter(character)
        }.value
    }

    /// Delete a character file
    func deleteCharacterFile(id: UUID) {
        let characterURL = charactersDirectory.appendingPathComponent("\(id.uuidString).json")

        do {
            try FileManager.default.removeItem(at: characterURL)
            LoggerService.storage.info("🗑️ Character file deleted: \(id)")
        } catch {
            LoggerService.storage.warning("⚠️ Failed to delete character file \(id): \(error.localizedDescription)")
        }
    }

    // MARK: - Update Character

    /// Updates a character (synchronous)
    @discardableResult
    func updateCharacter(_ character: Character, in settings: inout AppSettings) -> Result<Void, Error> {
        // Save the character to its individual file
        let characterResult = saveCharacter(character)

        // Ensure the character ID is in the settings
        if !settings.characterIds.contains(character.id) {
            settings.characterIds.append(character.id)
            let settingsResult = saveSettings(settings)
            // Return first error if either failed
            if case .failure(let error) = settingsResult {
                return .failure(error)
            }
        }

        return characterResult
    }

    /// Updates a character (asynchronous, prevents UI blocking for large chat histories)
    @discardableResult
    func updateCharacterAsync(_ character: Character, settings: AppSettings) async -> Result<Void, Error> {
        // Perform the update on a background queue
        return await Task.detached(priority: .background) { [weak self] in
            guard let self = self else {
                return .failure(NSError(domain: "StorageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Storage service deallocated"]))
            }

            var mutableSettings = settings
            return self.updateCharacter(character, in: &mutableSettings)
        }.value
    }

    // MARK: - Add Character

    @discardableResult
    func addCharacter(_ character: Character, to settings: inout AppSettings) -> Result<Void, Error> {
        // Save the character to its individual file
        let characterResult = saveCharacter(character)

        // Add the character ID to settings
        settings.characterIds.append(character.id)
        let settingsResult = saveSettings(settings)

        // Return first error if either failed
        if case .failure(let error) = characterResult {
            return .failure(error)
        }
        return settingsResult
    }

    // MARK: - Delete Character

    func deleteCharacter(id: UUID, from settings: inout AppSettings) {
        // Remove the character ID from settings
        settings.characterIds.removeAll { $0 == id }
        saveSettings(settings)

        // Delete the character file
        deleteCharacterFile(id: id)
    }

    // MARK: - Migration

    private func migrateToMultiFile(from oldData: Data, settings: inout AppSettings) {
        do {
            // Decode the old format with full Character objects
            let decoder = JSONDecoder()

            // Create a temporary struct to decode the old format
            struct OldAppSettings: Codable {
                var characters: [Character]
            }

            let oldSettings = try decoder.decode(OldAppSettings.self, from: oldData)

            LoggerService.storage.info("   Found \(oldSettings.characters.count) characters to migrate")

            // Save each character to its own file
            for character in oldSettings.characters {
                saveCharacter(character)
                LoggerService.storage.info("   ✓ Migrated character: \(character.name)")
            }

            // Update the settings with character IDs (already done in AppSettings.init(from:))
            // Just save the new format
            saveSettings(settings)

            LoggerService.storage.info("   Migration complete: \(oldSettings.characters.count) characters saved to individual files")
        } catch {
            LoggerService.storage.warning("⚠️ Migration failed: \(error.localizedDescription)")
        }
    }
}
