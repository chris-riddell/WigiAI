//
//  AppState.swift
//  WigiAI
//
//  AI Companion Desktop Widget
//  Centralized application state management
//

import Foundation
import SwiftUI

/// Centralized state container for the application
///
/// Manages all character data and app settings, providing a single source of truth
/// for the entire application. Separates state management from app lifecycle concerns.
///
/// **Architecture Benefits:**
/// - ✅ Separation of concerns (state vs. lifecycle)
/// - ✅ Easier testing (can be unit tested independently)
/// - ✅ Clearer data flow (all state changes through AppState)
/// - ✅ Better scalability (state logic isolated from AppDelegate)
@MainActor
class AppState: ObservableObject {
    // MARK: - Published State

    /// Global application settings
    @Published var settings: AppSettings

    /// All characters loaded from storage
    ///
    /// Characters are loaded from individual JSON files in
    /// `~/Library/Application Support/WigiAI/characters/`
    @Published var characters: [Character]

    // MARK: - Initialization

    /// Initializes AppState by loading settings and characters from storage
    init() {
        // Load settings from storage
        let loadedSettings = StorageService.shared.loadSettings()
        self.settings = loadedSettings

        // Load characters from individual files
        self.characters = StorageService.shared.loadCharacters(for: loadedSettings)

        LoggerService.app.debug("🏪 AppState initialized - loaded \(self.characters.count) characters")
    }

    // MARK: - Settings Management

    /// Updates application settings using a closure
    ///
    /// - Parameter updater: Closure that modifies the settings
    ///
    /// Example:
    /// ```swift
    /// appState.updateSettings { settings in
    ///     settings.launchOnStartup = true
    /// }
    /// ```
    func updateSettings(_ updater: (inout AppSettings) -> Void) {
        updater(&settings)
        StorageService.shared.saveSettings(settings)
        LoggerService.app.debug("⚙️ Settings updated")
    }

    // MARK: - Character Management

    /// Adds a new character to the app
    ///
    /// - Parameter character: The character to add
    /// - Note: Automatically saves to storage and updates settings
    func addCharacter(_ character: Character) {
        characters.append(character)
        StorageService.shared.addCharacter(character, to: &settings)
        LoggerService.app.debug("➕ Character added: \(character.name)")
    }

    /// Updates an existing character
    ///
    /// - Parameter character: The updated character (must have matching ID)
    /// - Note: Automatically saves to storage
    func updateCharacter(_ character: Character) {
        if let index = characters.firstIndex(where: { $0.id == character.id }) {
            characters[index] = character
            StorageService.shared.updateCharacter(character, in: &settings)
            LoggerService.app.debug("📝 Character updated: \(character.name)")
        } else {
            LoggerService.app.error("❌ Failed to find character with ID: \(character.id)")
        }
    }

    /// Deletes a character by ID
    ///
    /// - Parameter id: UUID of the character to delete
    /// - Note: Removes from storage and updates settings
    func deleteCharacter(id: UUID) {
        characters.removeAll { $0.id == id }
        StorageService.shared.deleteCharacter(id: id, from: &settings)
        LoggerService.app.debug("🗑️ Character deleted: \(id)")
    }

    /// Retrieves a character by ID
    ///
    /// - Parameter id: The character's UUID
    /// - Returns: The character if found, `nil` otherwise
    func character(withId id: UUID) -> Character? {
        characters.first(where: { $0.id == id })
    }

    // MARK: - Character Updates (Helper Methods)

    /// Updates a specific character using a closure
    ///
    /// - Parameters:
    ///   - id: UUID of the character to update
    ///   - updater: Closure that modifies the character
    ///
    /// Example:
    /// ```swift
    /// appState.updateCharacter(withId: characterId) { character in
    ///     character.name = "New Name"
    /// }
    /// ```
    func updateCharacter(withId id: UUID, _ updater: (inout Character) -> Void) {
        if let index = characters.firstIndex(where: { $0.id == id }) {
            updater(&characters[index])
            StorageService.shared.updateCharacter(characters[index], in: &settings)
            LoggerService.app.debug("📝 Character updated via closure: \(self.characters[index].name)")
        } else {
            LoggerService.app.error("❌ Failed to find character with ID: \(id)")
        }
    }

    /// Updates character widget position on screen
    ///
    /// - Parameters:
    ///   - id: UUID of the character
    ///   - position: New screen position (top-left corner)
    func updateCharacterPosition(id: UUID, position: CGPoint) {
        updateCharacter(withId: id) { character in
            character.position = position
        }
    }

    /// Sets notification badge visibility for a character widget
    ///
    /// - Parameters:
    ///   - characterId: UUID of the character
    ///   - enabled: Whether to show the badge
    func setNotificationBadge(for characterId: UUID, enabled: Bool) {
        updateCharacter(withId: characterId) { character in
            character.hasNotification = enabled
        }
    }

    /// Sets a pending reminder for a character
    ///
    /// - Parameters:
    ///   - characterId: UUID of the character
    ///   - reminderId: UUID of the reminder that triggered
    /// - Note: Sets notification badge and stores reminder for auto-message
    func setPendingReminder(for characterId: UUID, reminderId: UUID) {
        if let reminder = character(withId: characterId)?.reminders.first(where: { $0.id == reminderId }) {
            updateCharacter(withId: characterId) { character in
                character.pendingReminder = reminder
                character.hasNotification = true
            }
            LoggerService.app.debug("📬 Pending reminder set for character: \(characterId)")
        }
    }

    // MARK: - Validation & Utilities

    /// Validates and fixes off-screen character widget positions
    ///
    /// Checks if widgets are visible on screen and moves them to the main screen
    /// if they're completely off-screen (e.g., after monitor disconnect).
    func validateCharacterPositions() {
        guard let screen = NSScreen.main else {
            LoggerService.app.warning("⚠️ No main screen found, skipping position validation")
            return
        }

        let widgetSize: CGFloat = 100
        var hasChanges = false

        for (index, character) in characters.enumerated() {
            let validatedPosition = validatePosition(character.position, widgetSize: widgetSize, screen: screen)
            if validatedPosition != character.position {
                LoggerService.app.warning("⚠️ Widget '\(character.name)' was off-screen")
                LoggerService.app.debug("   Original: \(NSStringFromPoint(character.position))")
                LoggerService.app.debug("   Adjusted: \(NSStringFromPoint(validatedPosition))")

                characters[index].position = validatedPosition
                StorageService.shared.saveCharacter(characters[index])
                hasChanges = true
            }
        }

        if hasChanges {
            LoggerService.app.debug("💾 Adjusted positions saved")
        } else {
            LoggerService.app.info("✅ All widget positions valid")
        }
    }

    private func validatePosition(_ position: CGPoint, widgetSize: CGFloat, screen: NSScreen) -> CGPoint {
        let widgetRect = NSRect(origin: position, size: NSSize(width: widgetSize, height: widgetSize))

        // Check if widget overlaps with ANY screen (at least 50px visible)
        for currentScreen in NSScreen.screens {
            let intersection = widgetRect.intersection(currentScreen.visibleFrame)
            if intersection.width >= 50 && intersection.height >= 50 {
                return position  // Valid position
            }
        }

        // Widget not visible - move to main screen
        let screenFrame = screen.visibleFrame
        return CGPoint(
            x: screenFrame.minX + 100,
            y: screenFrame.minY + 100
        )
    }

    /// Calculates an optimal position for a new character widget
    ///
    /// - Returns: Screen position that avoids overlapping existing widgets
    /// - Note: Attempts to place new widgets near existing ones in a logical pattern
    func calculateSmartPosition() -> CGPoint {
        let widgetSize: CGFloat = 120
        let verticalSpacing: CGFloat = 30

        guard !characters.isEmpty else {
            return CGPoint(x: 100, y: 300)
        }

        let referencePosition = characters.last?.position ?? CGPoint(x: 100, y: 300)
        let existingPositions = characters.map { $0.position }

        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(referencePosition) }) ?? NSScreen.main else {
            return CGPoint(x: referencePosition.x, y: referencePosition.y + widgetSize + verticalSpacing)
        }

        let screenFrame = screen.visibleFrame

        // Try positions: below, above, right, left
        let testPositions = [
            CGPoint(x: referencePosition.x, y: referencePosition.y - widgetSize - verticalSpacing),
            CGPoint(x: referencePosition.x, y: referencePosition.y + widgetSize + verticalSpacing),
            CGPoint(x: referencePosition.x + widgetSize + verticalSpacing, y: referencePosition.y),
            CGPoint(x: referencePosition.x - widgetSize - verticalSpacing, y: referencePosition.y)
        ]

        for testPosition in testPositions {
            if isPositionAvailable(testPosition, existingPositions: existingPositions, widgetSize: widgetSize) &&
               screenFrame.contains(testPosition) {
                return testPosition
            }
        }

        // Fallback: offset from reference
        return CGPoint(x: referencePosition.x + 30, y: referencePosition.y - 30)
    }

    private func isPositionAvailable(_ position: CGPoint, existingPositions: [CGPoint], widgetSize: CGFloat) -> Bool {
        let testRect = CGRect(x: position.x, y: position.y, width: widgetSize, height: widgetSize)

        for existingPos in existingPositions {
            let existingRect = CGRect(x: existingPos.x, y: existingPos.y, width: widgetSize, height: widgetSize)
            if testRect.intersects(existingRect) {
                return false
            }
        }

        return true
    }
}
