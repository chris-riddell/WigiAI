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

    /// Pre-configured habits for this character
    let habits: [HabitTemplate]

    /// Pre-configured reminders for this character
    let reminders: [ReminderTemplate]

    /// Habit template for character library
    struct HabitTemplate: Codable {
        /// Name of the habit
        let name: String

        /// Target or goal description
        let targetDescription: String

        /// Frequency type: "daily", "weekdays", "weekends", "custom"
        let frequency: String

        /// Custom days when habit is active (for "custom" frequency)
        let customDays: [Int]?

        /// Optional reminder time in HH:mm format
        let reminderTime: String?
    }

    /// Reminder template for character library
    struct ReminderTemplate: Codable {
        /// Time in HH:mm format
        let time: String

        /// Reminder text sent to AI for personalization
        let reminderText: String
    }

    /// Converts this template into a fully-configured Character instance
    ///
    /// - Returns: A new `Character` with all habits and reminders configured
    /// - Note: Linked reminders are automatically created for habits with reminder times
    func toCharacter() -> Character {
        // Convert habit templates to habits
        let habits = self.habits.map { template -> Habit in
            let frequency: HabitFrequency
            switch template.frequency {
            case "daily":
                frequency = .daily
            case "weekdays":
                frequency = .weekdays
            case "weekends":
                frequency = .weekends
            case "custom":
                frequency = .custom
            default:
                frequency = .daily
            }

            // Parse reminder time if present
            let reminderTime: Date? = {
                guard let timeString = template.reminderTime else { return nil }
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                return formatter.date(from: timeString)
            }()

            return Habit(
                name: template.name,
                targetDescription: template.targetDescription,
                frequency: frequency,
                customDays: template.customDays != nil ? Set(template.customDays!) : nil,
                isEnabled: true,
                reminderTime: reminderTime
            )
        }

        // Convert reminder templates to reminders
        var reminders = self.reminders.map { template -> Reminder in
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            let time = formatter.date(from: template.time) ?? Date()

            return Reminder(
                time: time,
                reminderText: template.reminderText,
                isEnabled: true
            )
        }

        // Create linked reminders for habits that have reminder times
        for habit in habits {
            if let reminderTime = habit.reminderTime {
                let linkedReminder = Reminder(
                    time: reminderTime,
                    reminderText: "Time to check in! \(habit.targetDescription)",
                    isEnabled: true,
                    linkedHabitId: habit.id
                )
                reminders.append(linkedReminder)
            }
        }

        return Character(
            name: self.name,
            masterPrompt: self.masterPrompt,
            avatarAsset: self.avatar,
            reminders: reminders,
            habits: habits
        )
    }
}
