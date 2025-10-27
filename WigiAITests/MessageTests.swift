//
//  MessageTests.swift
//  WigiAITests
//
//  Unit tests for Message model
//

import XCTest
@testable import WigiAI

final class MessageTests: XCTestCase {

    // MARK: - Initialization Tests

    func testMessage_DefaultInitialization() {
        // Test initialization with default timestamp
        let message = Message(role: "user", content: "Hello")

        XCTAssertNotNil(message.id)
        XCTAssertEqual(message.role, "user")
        XCTAssertEqual(message.content, "Hello")
        XCTAssertNotNil(message.timestamp)
    }

    func testMessage_CustomInitialization() {
        // Test initialization with custom values
        let id = UUID()
        let timestamp = Date(timeIntervalSince1970: 1000000)
        let message = Message(id: id, role: "assistant", content: "Hi there!", timestamp: timestamp)

        XCTAssertEqual(message.id, id)
        XCTAssertEqual(message.role, "assistant")
        XCTAssertEqual(message.content, "Hi there!")
        XCTAssertEqual(message.timestamp, timestamp)
    }

    func testMessage_UserRole() {
        // Test user role message
        let message = Message(role: "user", content: "User message")

        XCTAssertEqual(message.role, "user")
    }

    func testMessage_AssistantRole() {
        // Test assistant role message
        let message = Message(role: "assistant", content: "Assistant response")

        XCTAssertEqual(message.role, "assistant")
    }

    func testMessage_SystemRole() {
        // Test system role message
        let message = Message(role: "system", content: "System instruction")

        XCTAssertEqual(message.role, "system")
    }

    // MARK: - Content Tests

    func testMessage_EmptyContent() {
        // Test message with empty content
        let message = Message(role: "user", content: "")

        XCTAssertEqual(message.content, "")
    }

    func testMessage_MultilineContent() {
        // Test message with multiline content
        let content = """
        This is a multiline
        message content
        with several lines
        """
        let message = Message(role: "user", content: content)

        XCTAssertEqual(message.content, content)
        XCTAssertTrue(message.content.contains("\n"))
    }

    func testMessage_LongContent() {
        // Test message with long content
        let longContent = String(repeating: "a", count: 10000)
        let message = Message(role: "user", content: longContent)

        XCTAssertEqual(message.content.count, 10000)
    }

    func testMessage_SpecialCharactersContent() {
        // Test message with special characters
        let content = "Special chars: @#$%^&*()_+-=[]{}|;':\",./<>?\\`~"
        let message = Message(role: "user", content: content)

        XCTAssertEqual(message.content, content)
    }

    func testMessage_UnicodeContent() {
        // Test message with unicode/emoji content
        let content = "Hello 👋 World 🌍 with émojis and ñ characters"
        let message = Message(role: "user", content: content)

        XCTAssertEqual(message.content, content)
    }

    // MARK: - Encoding/Decoding Tests

    func testMessage_EncodeDecode() throws {
        // Test basic encode/decode round-trip
        let original = Message(
            role: "user",
            content: "Test message",
            timestamp: Date(timeIntervalSince1970: 1234567890)
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Message.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.role, original.role)
        XCTAssertEqual(decoded.content, original.content)
        XCTAssertEqual(decoded.timestamp.timeIntervalSince1970, original.timestamp.timeIntervalSince1970, accuracy: 0.001)
    }

    func testMessage_EncodeDecodeWithSpecialCharacters() throws {
        // Test encoding/decoding with special characters
        let content = "Content with \"quotes\", backslash\\, and newlines\n"
        let message = Message(role: "user", content: content)

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(Message.self, from: data)

        XCTAssertEqual(decoded.content, content)
    }

    func testMessage_JSONFormat() throws {
        // Test that JSON encoding produces expected format
        let message = Message(
            id: UUID(),
            role: "user",
            content: "Test"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(message)
        let jsonString = String(data: data, encoding: .utf8)!

        XCTAssertTrue(jsonString.contains("\"role\""))
        XCTAssertTrue(jsonString.contains("\"content\""))
        XCTAssertTrue(jsonString.contains("\"timestamp\""))
        XCTAssertTrue(jsonString.contains("\"id\""))
    }

    func testMessage_DecodeFromJSON() throws {
        // Test decoding from JSON string
        let jsonString = """
        {
            "id": "\(UUID().uuidString)",
            "role": "assistant",
            "content": "Response text",
            "timestamp": 1234567890.0
        }
        """

        let data = jsonString.data(using: .utf8)!
        let message = try JSONDecoder().decode(Message.self, from: data)

        XCTAssertEqual(message.role, "assistant")
        XCTAssertEqual(message.content, "Response text")
    }

    // MARK: - Hashable Tests

    func testMessage_Hashable() {
        // Test that messages are hashable
        let msg1 = Message(role: "user", content: "Message 1")
        let msg2 = Message(role: "user", content: "Message 2")
        let msg3 = Message(id: msg1.id, role: "user", content: "Message 1")

        var set = Set<Message>()
        set.insert(msg1)
        set.insert(msg2)

        XCTAssertEqual(set.count, 2)

        // Same ID should be considered equal
        set.insert(msg3)
        XCTAssertEqual(set.count, 2, "Messages with same ID should be equal")
    }

    func testMessage_Equatable() {
        // Test message equality (based on ID for Identifiable conformance)
        let id = UUID()
        let timestamp = Date()
        let msg1 = Message(id: id, role: "user", content: "Content 1", timestamp: timestamp)
        let msg2 = Message(id: id, role: "user", content: "Content 1", timestamp: timestamp)
        let msg3 = Message(id: id, role: "assistant", content: "Content 1", timestamp: timestamp)
        let msg4 = Message(role: "user", content: "Content 1", timestamp: timestamp)

        XCTAssertEqual(msg1, msg2, "Messages with identical fields should be equal")
        XCTAssertEqual(msg1, msg3, "Messages with same ID should be equal (Identifiable semantics)")
        XCTAssertNotEqual(msg1, msg4, "Messages with different IDs should not be equal")
    }

    // MARK: - Array Operations Tests

    func testMessage_ArrayOfMessages() {
        // Test working with arrays of messages
        let messages = [
            Message(role: "user", content: "Hello"),
            Message(role: "assistant", content: "Hi!"),
            Message(role: "user", content: "How are you?"),
            Message(role: "assistant", content: "I'm good!")
        ]

        XCTAssertEqual(messages.count, 4)

        let userMessages = messages.filter { $0.role == "user" }
        XCTAssertEqual(userMessages.count, 2)

        let assistantMessages = messages.filter { $0.role == "assistant" }
        XCTAssertEqual(assistantMessages.count, 2)
    }

    func testMessage_SortByTimestamp() {
        // Test sorting messages by timestamp
        let now = Date()
        let messages = [
            Message(role: "user", content: "Second", timestamp: now.addingTimeInterval(60)),
            Message(role: "user", content: "First", timestamp: now),
            Message(role: "user", content: "Third", timestamp: now.addingTimeInterval(120))
        ]

        let sorted = messages.sorted { $0.timestamp < $1.timestamp }

        XCTAssertEqual(sorted[0].content, "First")
        XCTAssertEqual(sorted[1].content, "Second")
        XCTAssertEqual(sorted[2].content, "Third")
    }

    // MARK: - Timestamp Tests

    func testMessage_TimestampPrecision() {
        // Test that timestamp maintains precision
        let timestamp = Date()
        let message = Message(role: "user", content: "Test", timestamp: timestamp)

        XCTAssertEqual(message.timestamp.timeIntervalSince1970, timestamp.timeIntervalSince1970, accuracy: 0.001)
    }

    func testMessage_OldTimestamp() {
        // Test message with old timestamp
        let oldDate = Date(timeIntervalSince1970: 0) // Jan 1, 1970
        let message = Message(role: "user", content: "Old message", timestamp: oldDate)

        XCTAssertEqual(message.timestamp, oldDate)
    }

    func testMessage_FutureTimestamp() {
        // Test message with future timestamp
        let futureDate = Date(timeIntervalSinceNow: 86400 * 365) // 1 year from now
        let message = Message(role: "user", content: "Future message", timestamp: futureDate)

        XCTAssertEqual(message.timestamp, futureDate)
    }

    // MARK: - Role Validation Tests

    func testMessage_CustomRole() {
        // Test that any string can be used as a role (not limited to user/assistant/system)
        let message = Message(role: "custom-role", content: "Test")

        XCTAssertEqual(message.role, "custom-role")
    }

    func testMessage_EmptyRole() {
        // Test message with empty role
        let message = Message(role: "", content: "Test")

        XCTAssertEqual(message.role, "")
    }

    // MARK: - Identifiable Tests

    func testMessage_UniqueIDs() {
        // Test that each message gets a unique ID
        let msg1 = Message(role: "user", content: "Test")
        let msg2 = Message(role: "user", content: "Test")

        XCTAssertNotEqual(msg1.id, msg2.id, "Each message should have a unique ID")
    }

    func testMessage_IDPersistence() throws {
        // Test that ID persists through encoding/decoding
        let original = Message(role: "user", content: "Test")
        let originalID = original.id

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Message.self, from: data)

        XCTAssertEqual(decoded.id, originalID, "ID should persist through encoding/decoding")
    }
}
