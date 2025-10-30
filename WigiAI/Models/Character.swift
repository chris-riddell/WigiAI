//
//  Character.swift
//  WigiAI
//
//  AI Companion Desktop Widget
//

import Foundation

/// AI companion character with personality, memory, and tracking capabilities
///
/// Characters are persistent desktop widgets that maintain conversation history,
/// track habits, send reminders, and provide personalized AI interactions.
/// Each character is stored in its own JSON file for scalability.
struct Character: Codable, Identifiable, Hashable {
    /// Unique identifier for the character
    let id: UUID

    /// Display name of the character
    var name: String

    /// AI personality and behavior instructions (sent as system prompt)
    ///
    /// This defines the character's role, personality, and interaction style.
    /// Cached by OpenAI for 50% cost reduction on repeated requests.
    var masterPrompt: String

    /// Asset name for the character's avatar (e.g., "person", "professional", "scientist", "artist")
    var avatarAsset: String

    /// Screen position of the character widget (top-left corner)
    var position: CGPoint

    /// Unified activities (reminders + habit tracking)
    ///
    /// Replaces the legacy `reminders` and `habits` arrays with a single flexible model.
    /// Activities can be simple reminders or full habit trackers with completion history.
    var activities: [Activity]

    /// Legacy reminders (deprecated, use activities instead)
    ///
    /// Maintained for backward compatibility during migration.
    /// When decoding old character files, these are automatically converted to activities.
    @available(*, deprecated, message: "Use activities array instead")
    var reminders: [Reminder]

    /// Legacy habits (deprecated, use activities instead)
    ///
    /// Maintained for backward compatibility during migration.
    /// When decoding old character files, these are automatically converted to activities.
    @available(*, deprecated, message: "Use activities array instead")
    var habits: [Habit]

    /// Constantly updated AI-generated summary of the conversation
    ///
    /// Automatically refreshed every 5 minutes or 5 messages during active conversation.
    /// Provides long-term context without sending full chat history to API.
    var persistentContext: String

    /// Complete conversation history with the user
    var chatHistory: [Message]

    /// Optional per-character model override (e.g., "gpt-4", "gpt-3.5-turbo")
    ///
    /// If `nil`, uses global API config model
    var customModel: String?

    /// Whether the widget shows a notification badge
    var hasNotification: Bool

    /// Activity waiting to be acknowledged (triggers automatic message)
    ///
    /// This replaces the old `pendingReminder` field. For backward compatibility,
    /// we store the activity ID here instead of the full Activity object.
    var pendingActivityId: UUID?

    /// Legacy pending reminder (deprecated, use pendingActivityId instead)
    @available(*, deprecated, message: "Use pendingActivityId instead")
    var pendingReminder: Reminder?

    /// Optional per-character voice override for text-to-speech
    ///
    /// If `nil`, uses global voice settings
    var customVoiceIdentifier: String?

    /// Optional per-character speech rate override (0.0 to 1.0)
    ///
    /// If `nil`, uses global voice settings
    var customSpeechRate: Float?

    init(
        id: UUID = UUID(),
        name: String,
        masterPrompt: String,
        avatarAsset: String = "person",
        position: CGPoint = CGPoint(x: 100, y: 100),
        activities: [Activity] = [],
        reminders: [Reminder] = [],
        habits: [Habit] = [],
        persistentContext: String = "",
        chatHistory: [Message] = [],
        customModel: String? = nil,
        hasNotification: Bool = false,
        pendingActivityId: UUID? = nil,
        pendingReminder: Reminder? = nil,
        customVoiceIdentifier: String? = nil,
        customSpeechRate: Float? = nil
    ) {
        self.id = id
        self.name = name
        self.masterPrompt = masterPrompt
        self.avatarAsset = avatarAsset
        self.position = position
        self.activities = activities
        self.reminders = reminders
        self.habits = habits
        self.persistentContext = persistentContext
        self.chatHistory = chatHistory
        self.customModel = customModel
        self.hasNotification = hasNotification
        self.pendingActivityId = pendingActivityId
        self.pendingReminder = pendingReminder
        self.customVoiceIdentifier = customVoiceIdentifier
        self.customSpeechRate = customSpeechRate
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, masterPrompt, avatarAsset, position
        case activities  // New unified field
        case reminders, habits  // Legacy fields for backward compatibility
        case persistentContext, chatHistory, customModel, hasNotification
        case pendingActivityId, pendingReminder  // New + legacy
        case customVoiceIdentifier, customSpeechRate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(masterPrompt, forKey: .masterPrompt)
        try container.encode(avatarAsset, forKey: .avatarAsset)
        try container.encode(position, forKey: .position)

        // Always encode activities (new format)
        try container.encode(activities, forKey: .activities)

        // Don't encode legacy reminders/habits to force migration to new format
        // If you need to maintain backward compatibility with old readers, encode them too:
        // try container.encode(reminders, forKey: .reminders)
        // try container.encode(habits, forKey: .habits)

        try container.encode(persistentContext, forKey: .persistentContext)
        try container.encode(chatHistory, forKey: .chatHistory)
        try container.encodeIfPresent(customModel, forKey: .customModel)
        try container.encode(hasNotification, forKey: .hasNotification)
        try container.encodeIfPresent(pendingActivityId, forKey: .pendingActivityId)
        try container.encodeIfPresent(customVoiceIdentifier, forKey: .customVoiceIdentifier)
        try container.encodeIfPresent(customSpeechRate, forKey: .customSpeechRate)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        masterPrompt = try container.decode(String.self, forKey: .masterPrompt)
        avatarAsset = try container.decode(String.self, forKey: .avatarAsset)
        position = try container.decode(CGPoint.self, forKey: .position)
        persistentContext = try container.decode(String.self, forKey: .persistentContext)
        chatHistory = try container.decode([Message].self, forKey: .chatHistory)
        customModel = try container.decodeIfPresent(String.self, forKey: .customModel)
        hasNotification = try container.decode(Bool.self, forKey: .hasNotification)
        customVoiceIdentifier = try container.decodeIfPresent(String.self, forKey: .customVoiceIdentifier)
        customSpeechRate = try container.decodeIfPresent(Float.self, forKey: .customSpeechRate)

        // Try to load activities first (new format)
        if let loadedActivities = try? container.decodeIfPresent([Activity].self, forKey: .activities) {
            activities = loadedActivities

            // For backward compatibility, populate legacy arrays from activities
            reminders = []
            habits = activities.filter { $0.isTrackingEnabled }.map { activity in
                Habit(
                    id: activity.id,
                    name: activity.name,
                    targetDescription: activity.description,
                    frequency: {
                        switch activity.frequency {
                        case .daily: return .daily
                        case .weekdays: return .weekdays
                        case .weekends: return .weekends
                        case .custom: return .custom
                        case .oneTime: return .daily
                        }
                    }(),
                    customDays: activity.customDays,
                    isEnabled: activity.isEnabled,
                    reminderTime: activity.scheduledTime,
                    completionDates: activity.completionDates,
                    skipDates: activity.skipDates,
                    createdDate: activity.createdDate
                )
            }

            pendingActivityId = try container.decodeIfPresent(UUID.self, forKey: .pendingActivityId)
            pendingReminder = nil

        } else {
            // Legacy format: load reminders and habits separately, then migrate
            reminders = try container.decode([Reminder].self, forKey: .reminders)
            habits = try container.decodeIfPresent([Habit].self, forKey: .habits) ?? []
            pendingReminder = try container.decodeIfPresent(Reminder.self, forKey: .pendingReminder)

            // Perform migration
            var migratedActivities: [Activity] = []
            var processedReminderIds = Set<UUID>()

            // Migrate habits first
            for habit in habits {
                if let linkedReminder = reminders.first(where: { $0.linkedHabitId == habit.id }) {
                    let activity = Activity.fromLinkedReminderAndHabit(
                        reminder: linkedReminder,
                        habit: habit
                    )
                    migratedActivities.append(activity)
                    processedReminderIds.insert(linkedReminder.id)
                } else {
                    let activity = Activity.fromHabit(habit)
                    migratedActivities.append(activity)
                }
            }

            // Migrate standalone reminders
            for reminder in reminders {
                if !processedReminderIds.contains(reminder.id) && reminder.linkedHabitId == nil {
                    let activity = Activity.fromReminder(reminder)
                    migratedActivities.append(activity)
                }
            }

            activities = migratedActivities

            // Migrate pending reminder to pending activity
            if let pending = pendingReminder {
                pendingActivityId = pending.linkedHabitId ?? pending.id
            } else {
                pendingActivityId = nil
            }

            // Capture values for logging (can't use self in escaping closure during init)
            let characterName = name
            let habitCount = habits.count
            let reminderCount = reminders.count
            let activityCount = migratedActivities.count
            LoggerService.app.info("✅ Auto-migrated character '\(characterName)': \(habitCount) habits + \(reminderCount) reminders → \(activityCount) activities")
        }
    }
}
