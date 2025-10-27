//
//  CharacterTests.swift
//  WigiAITests
//
//  Unit tests for Character model encoding/decoding and backward compatibility
//

import XCTest
@testable import WigiAI

final class CharacterTests: XCTestCase {

    // MARK: - Initialization Tests

    func testCharacter_DefaultInitialization() {
        // Test default initialization
        let character = Character(
            name: "Test Character",
            masterPrompt: "You are a test character."
        )

        XCTAssertNotNil(character.id)
        XCTAssertEqual(character.name, "Test Character")
        XCTAssertEqual(character.masterPrompt, "You are a test character.")
        XCTAssertEqual(character.avatarAsset, "person", "Should default to 'person' avatar")
        XCTAssertEqual(character.position, CGPoint(x: 100, y: 100), "Should default to (100, 100)")
        XCTAssertTrue(character.reminders.isEmpty)
        XCTAssertTrue(character.chatHistory.isEmpty)
        XCTAssertTrue(character.habits.isEmpty)
        XCTAssertEqual(character.persistentContext, "")
        XCTAssertNil(character.customModel)
        XCTAssertFalse(character.hasNotification)
        XCTAssertNil(character.pendingReminder)
        XCTAssertNil(character.customVoiceIdentifier)
        XCTAssertNil(character.customSpeechRate)
    }

    func testCharacter_CustomInitialization() {
        // Test initialization with custom values
        let id = UUID()
        let position = CGPoint(x: 200, y: 300)
        let message = Message(role: "user", content: "Hello!")
        let habit = Habit(name: "Exercise", targetDescription: "30 min workout")
        let reminder = Reminder(time: Date(), reminderText: "Check in")

        let character = Character(
            id: id,
            name: "Custom",
            masterPrompt: "Custom prompt",
            avatarAsset: "scientist",
            position: position,
            reminders: [reminder],
            persistentContext: "Context text",
            chatHistory: [message],
            customModel: "gpt-4",
            hasNotification: true,
            pendingReminder: reminder,
            customVoiceIdentifier: "com.apple.voice.compact.en-US.Samantha",
            customSpeechRate: 0.5,
            habits: [habit]
        )

        XCTAssertEqual(character.id, id)
        XCTAssertEqual(character.name, "Custom")
        XCTAssertEqual(character.avatarAsset, "scientist")
        XCTAssertEqual(character.position, position)
        XCTAssertEqual(character.reminders.count, 1)
        XCTAssertEqual(character.chatHistory.count, 1)
        XCTAssertEqual(character.habits.count, 1)
        XCTAssertEqual(character.persistentContext, "Context text")
        XCTAssertEqual(character.customModel, "gpt-4")
        XCTAssertTrue(character.hasNotification)
        XCTAssertNotNil(character.pendingReminder)
        XCTAssertEqual(character.customVoiceIdentifier, "com.apple.voice.compact.en-US.Samantha")
        XCTAssertEqual(character.customSpeechRate, 0.5)
    }

    // MARK: - Encoding/Decoding Tests

    func testCharacter_EncodeDecode() throws {
        // Test basic encode/decode round-trip
        let original = Character(
            name: "Test",
            masterPrompt: "Test prompt",
            avatarAsset: "professional",
            position: CGPoint(x: 150, y: 250),
            persistentContext: "Some context"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Character.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.masterPrompt, original.masterPrompt)
        XCTAssertEqual(decoded.avatarAsset, original.avatarAsset)
        XCTAssertEqual(decoded.position, original.position)
        XCTAssertEqual(decoded.persistentContext, original.persistentContext)
    }

    func testCharacter_EncodeDecodeWithMessages() throws {
        // Test encoding/decoding with chat history
        let messages = [
            Message(role: "user", content: "Hello"),
            Message(role: "assistant", content: "Hi there!"),
            Message(role: "user", content: "How are you?")
        ]

        let character = Character(
            name: "Test",
            masterPrompt: "Test",
            chatHistory: messages
        )

        let data = try JSONEncoder().encode(character)
        let decoded = try JSONDecoder().decode(Character.self, from: data)

        XCTAssertEqual(decoded.chatHistory.count, 3)
        XCTAssertEqual(decoded.chatHistory[0].role, "user")
        XCTAssertEqual(decoded.chatHistory[0].content, "Hello")
        XCTAssertEqual(decoded.chatHistory[1].role, "assistant")
        XCTAssertEqual(decoded.chatHistory[2].content, "How are you?")
    }

    func testCharacter_EncodeDecodeWithHabits() throws {
        // Test encoding/decoding with habits
        let habits = [
            Habit(name: "Exercise", targetDescription: "30 min", frequency: .daily),
            Habit(name: "Read", targetDescription: "20 pages", frequency: .weekdays)
        ]

        let character = Character(
            name: "Test",
            masterPrompt: "Test",
            habits: habits
        )

        let data = try JSONEncoder().encode(character)
        let decoded = try JSONDecoder().decode(Character.self, from: data)

        XCTAssertEqual(decoded.habits.count, 2)
        XCTAssertEqual(decoded.habits[0].name, "Exercise")
        XCTAssertEqual(decoded.habits[0].frequency, .daily)
        XCTAssertEqual(decoded.habits[1].name, "Read")
        XCTAssertEqual(decoded.habits[1].frequency, .weekdays)
    }

    func testCharacter_EncodeDecodeWithReminders() throws {
        // Test encoding/decoding with reminders
        let reminders = [
            Reminder(time: Date(), reminderText: "Morning check-in", isEnabled: true),
            Reminder(time: Date(), reminderText: "Evening reflection", isEnabled: false)
        ]

        let character = Character(
            name: "Test",
            masterPrompt: "Test",
            reminders: reminders
        )

        let data = try JSONEncoder().encode(character)
        let decoded = try JSONDecoder().decode(Character.self, from: data)

        XCTAssertEqual(decoded.reminders.count, 2)
        XCTAssertEqual(decoded.reminders[0].reminderText, "Morning check-in")
        XCTAssertTrue(decoded.reminders[0].isEnabled)
        XCTAssertEqual(decoded.reminders[1].reminderText, "Evening reflection")
        XCTAssertFalse(decoded.reminders[1].isEnabled)
    }

    func testCharacter_EncodeDecodeWithOptionalFields() throws {
        // Test encoding/decoding with all optional fields set
        let character = Character(
            name: "Test",
            masterPrompt: "Test",
            customModel: "gpt-4-turbo",
            hasNotification: true,
            customVoiceIdentifier: "com.apple.voice.compact.en-US.Zoe",
            customSpeechRate: 0.75
        )

        let data = try JSONEncoder().encode(character)
        let decoded = try JSONDecoder().decode(Character.self, from: data)

        XCTAssertEqual(decoded.customModel, "gpt-4-turbo")
        XCTAssertTrue(decoded.hasNotification)
        XCTAssertEqual(decoded.customVoiceIdentifier, "com.apple.voice.compact.en-US.Zoe")
        XCTAssertEqual(decoded.customSpeechRate, 0.75)
    }


    // MARK: - Hashable Tests

    func testCharacter_Hashable() {
        // Test that characters are hashable
        let char1 = Character(name: "Test1", masterPrompt: "Prompt1")
        let char2 = Character(name: "Test2", masterPrompt: "Prompt2")
        let char3 = Character(id: char1.id, name: "Test1", masterPrompt: "Prompt1")

        var set = Set<Character>()
        set.insert(char1)
        set.insert(char2)

        XCTAssertEqual(set.count, 2)

        // Same ID should be considered equal
        set.insert(char3)
        XCTAssertEqual(set.count, 2, "Characters with same ID should be equal")
    }

    func testCharacter_Equatable() {
        // Test character equality (compares all fields, not just ID)
        let id = UUID()
        let char1 = Character(id: id, name: "Test", masterPrompt: "Prompt")
        let char2 = Character(id: id, name: "Test", masterPrompt: "Prompt")
        let char3 = Character(id: id, name: "Different Name", masterPrompt: "Prompt")
        let char4 = Character(name: "Test", masterPrompt: "Prompt")

        XCTAssertEqual(char1, char2, "Characters with identical fields should be equal")
        XCTAssertNotEqual(char1, char3, "Characters with different names should not be equal")
        XCTAssertNotEqual(char1, char4, "Characters with different IDs should not be equal")
    }

    // MARK: - Position Tests

    func testCharacter_Position() {
        // Test position handling
        let position = CGPoint(x: 500, y: 600)
        let character = Character(
            name: "Test",
            masterPrompt: "Test",
            position: position
        )

        XCTAssertEqual(character.position.x, 500)
        XCTAssertEqual(character.position.y, 600)
    }

    func testCharacter_PositionEncoding() throws {
        // Test that position is properly encoded/decoded
        let character = Character(
            name: "Test",
            masterPrompt: "Test",
            position: CGPoint(x: 123.45, y: 678.90)
        )

        let data = try JSONEncoder().encode(character)
        let decoded = try JSONDecoder().decode(Character.self, from: data)

        XCTAssertEqual(decoded.position.x, 123.45, accuracy: 0.001)
        XCTAssertEqual(decoded.position.y, 678.90, accuracy: 0.001)
    }

    // MARK: - Notification State Tests

    func testCharacter_NotificationBadge() {
        // Test notification badge state
        var character = Character(name: "Test", masterPrompt: "Test")

        XCTAssertFalse(character.hasNotification)

        character.hasNotification = true
        XCTAssertTrue(character.hasNotification)
    }

    func testCharacter_PendingReminder() {
        // Test pending reminder
        let reminder = Reminder(time: Date(), reminderText: "Test reminder")
        var character = Character(name: "Test", masterPrompt: "Test")

        XCTAssertNil(character.pendingReminder)

        character.pendingReminder = reminder
        XCTAssertNotNil(character.pendingReminder)
        XCTAssertEqual(character.pendingReminder?.reminderText, "Test reminder")
    }

    // MARK: - Voice Settings Tests

    func testCharacter_CustomVoiceSettings() {
        // Test custom voice settings
        let character = Character(
            name: "Test",
            masterPrompt: "Test",
            customVoiceIdentifier: "com.apple.voice.compact.en-US.Samantha",
            customSpeechRate: 0.6
        )

        XCTAssertEqual(character.customVoiceIdentifier, "com.apple.voice.compact.en-US.Samantha")
        XCTAssertEqual(character.customSpeechRate, 0.6)
    }

    func testCharacter_VoiceSettingsEncoding() throws {
        // Test voice settings are encoded/decoded properly
        let character = Character(
            name: "Test",
            masterPrompt: "Test",
            customVoiceIdentifier: "com.apple.voice.premium.en-US.Zoe",
            customSpeechRate: 0.8
        )

        let data = try JSONEncoder().encode(character)
        let decoded = try JSONDecoder().decode(Character.self, from: data)

        XCTAssertEqual(decoded.customVoiceIdentifier, "com.apple.voice.premium.en-US.Zoe")
        XCTAssertEqual(decoded.customSpeechRate, 0.8)
    }
}
