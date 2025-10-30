//
//  CharacterTemplate.swift
//  WigiAI
//
//  Character library template model
//

import Foundation

/// Pre-configured character template from the character library
///
/// Templates are loaded from JSON files in the app bundle and provide
/// ready-to-use characters with pre-configured habits, reminders, and personalities.
struct CharacterTemplate: Codable, Identifiable {
    /// Unique identifier for the template
    let id: String

    /// Display name of the character
    let name: String

    /// Category for organizing templates (e.g., "Productivity", "Health", "Learning")
    let category: String

    /// Description of the character's purpose and capabilities
    let description: String

    /// Avatar asset identifier
    let avatar: String

    /// AI personality and behavior instructions
    let masterPrompt: String

    /// Pre-configured activities for this character
    let activities: [ActivityTemplate]

    /// Activity template for character library
    struct ActivityTemplate: Codable {
        /// Name of the activity
        let name: String

        /// Description of the activity
        let description: String

        /// Frequency type: "daily", "weekdays", "weekends", "custom", "oneTime"
        let frequency: String

        /// Custom days when activity is active (for "custom" frequency)
        let customDays: [Int]?

        /// Optional notification time in HH:mm format
        let scheduledTime: String?

        /// Whether this activity tracks completions/streaks
        let isTrackingEnabled: Bool
    }

    /// Converts this template into a fully-configured Character instance
    ///
    /// - Returns: A new `Character` with all activities configured
    func toCharacter() -> Character {
        // Convert activity templates to activities
        let activities = self.activities.map { template -> Activity in
            let frequency: ActivityFrequency
            switch template.frequency {
            case "daily":
                frequency = .daily
            case "weekdays":
                frequency = .weekdays
            case "weekends":
                frequency = .weekends
            case "custom":
                frequency = .custom
            case "oneTime":
                frequency = .oneTime
            default:
                frequency = .daily
            }

            // Parse scheduled time if present
            let scheduledTime: Date? = {
                guard let timeString = template.scheduledTime else { return nil }
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                return formatter.date(from: timeString)
            }()

            return Activity(
                name: template.name,
                description: template.description,
                scheduledTime: scheduledTime,
                frequency: frequency,
                customDays: template.customDays != nil ? Set(template.customDays!) : nil,
                isTrackingEnabled: template.isTrackingEnabled,
                isEnabled: true
            )
        }

        return Character(
            name: self.name,
            masterPrompt: self.masterPrompt,
            avatarAsset: self.avatar,
            activities: activities
        )
    }
}
