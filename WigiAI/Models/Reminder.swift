//
//  Reminder.swift
//  WigiAI
//
//  AI Companion Desktop Widget
//

import Foundation

/// Represents a scheduled reminder for a character
///
/// Reminders trigger at a specific time each day and can optionally be linked
/// to a habit for integrated tracking. The reminder text is passed to the AI
/// for personalized notification messages.
struct Reminder: Codable, Identifiable, Hashable {
    /// Unique identifier for the reminder
    let id: UUID

    /// Time of day when the reminder should trigger (recurs daily)
    var time: Date

    /// Text description of the reminder, sent to AI for personalization
    var reminderText: String

    /// Whether the reminder is active
    var isEnabled: Bool

    /// Timestamp of the last time this reminder was triggered
    var lastTriggered: Date?

    /// Optional link to a habit (creates a habit-specific reminder)
    ///
    /// When set, this reminder is automatically synchronized with the associated habit's
    /// reminder time and is used to prompt habit completion.
    var linkedHabitId: UUID?

    /// Creates a new reminder
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - time: Time of day for the reminder
    ///   - reminderText: Description sent to AI for personalization
    ///   - isEnabled: Whether the reminder is active (defaults to `true`)
    ///   - lastTriggered: Last trigger timestamp (defaults to `nil`)
    ///   - linkedHabitId: Optional habit link (defaults to `nil`)
    init(id: UUID = UUID(), time: Date, reminderText: String, isEnabled: Bool = true, lastTriggered: Date? = nil, linkedHabitId: UUID? = nil) {
        self.id = id
        self.time = time
        self.reminderText = reminderText
        self.isEnabled = isEnabled
        self.lastTriggered = lastTriggered
        self.linkedHabitId = linkedHabitId
    }

    enum CodingKeys: String, CodingKey {
        case id, time, reminderText, isEnabled, lastTriggered, linkedHabitId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        time = try container.decode(Date.self, forKey: .time)
        reminderText = try container.decode(String.self, forKey: .reminderText)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        lastTriggered = try container.decodeIfPresent(Date.self, forKey: .lastTriggered)
        linkedHabitId = try container.decodeIfPresent(UUID.self, forKey: .linkedHabitId)
    }
}
