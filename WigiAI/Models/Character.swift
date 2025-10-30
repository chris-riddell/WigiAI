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
    /// Activities can be simple reminders or full habit trackers with completion history.
    var activities: [Activity]

    /// Constantly updated AI-generated summary of the conversation
    ///
    /// Automatically refreshed every 5 minutes or 5 messages during active conversation.
    /// Provides long-term context without sending full chat history to API.
    var persistentContext: String

    /// Complete conversation history with the user
    var chatHistory: [Message]

    /// Optional per-character model override (e.g., "gpt-4.1", "gpt-4.1-mini")
    ///
    /// If `nil`, uses global API config model
    var customModel: String?

    /// Whether the widget shows a notification badge
    var hasNotification: Bool

    /// Activity waiting to be acknowledged (triggers automatic message)
    var pendingActivityId: UUID?

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
        persistentContext: String = "",
        chatHistory: [Message] = [],
        customModel: String? = nil,
        hasNotification: Bool = false,
        pendingActivityId: UUID? = nil,
        customVoiceIdentifier: String? = nil,
        customSpeechRate: Float? = nil
    ) {
        self.id = id
        self.name = name
        self.masterPrompt = masterPrompt
        self.avatarAsset = avatarAsset
        self.position = position
        self.activities = activities
        self.persistentContext = persistentContext
        self.chatHistory = chatHistory
        self.customModel = customModel
        self.hasNotification = hasNotification
        self.pendingActivityId = pendingActivityId
        self.customVoiceIdentifier = customVoiceIdentifier
        self.customSpeechRate = customSpeechRate
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, masterPrompt, avatarAsset, position
        case activities
        case persistentContext, chatHistory, customModel, hasNotification
        case pendingActivityId
        case customVoiceIdentifier, customSpeechRate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(masterPrompt, forKey: .masterPrompt)
        try container.encode(avatarAsset, forKey: .avatarAsset)
        try container.encode(position, forKey: .position)
        try container.encode(activities, forKey: .activities)
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

        // Load activities (no migration needed - app unreleased)
        activities = try container.decode([Activity].self, forKey: .activities)
        pendingActivityId = try container.decodeIfPresent(UUID.self, forKey: .pendingActivityId)
    }
}
