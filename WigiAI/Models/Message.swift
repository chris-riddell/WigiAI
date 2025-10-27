//
//  Message.swift
//  WigiAI
//
//  AI Companion Desktop Widget
//

import Foundation

/// Represents a single message in a conversation between the user and an AI character
///
/// Messages are stored in a character's chat history and include metadata about
/// the sender role, content, and timestamp for proper conversation threading.
struct Message: Codable, Identifiable, Hashable {
    /// Unique identifier for the message
    let id: UUID

    /// Role of the message sender
    ///
    /// Valid values:
    /// - `"user"`: Message from the human user
    /// - `"assistant"`: Message from the AI character
    /// - `"system"`: System-level instruction or context
    let role: String

    /// The text content of the message
    let content: String

    /// When the message was created
    let timestamp: Date

    /// Creates a new message
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - role: Sender role ("user", "assistant", or "system")
    ///   - content: The message text
    ///   - timestamp: Creation time (defaults to current time)
    init(id: UUID = UUID(), role: String, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    // MARK: - Hashable & Equatable

    /// Messages are equal if they have the same ID (identity-based equality)
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }

    /// Hash based on ID only (consistent with Identifiable protocol)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
