//
//  AIServiceTests.swift
//  WigiAITests
//
//  Tests for AIService context building logic
//

import XCTest
@testable import WigiAI

final class AIServiceTests: XCTestCase {
    var aiService: AIService!
    var testCharacter: Character!

    override func setUp() {
        super.setUp()
        aiService = AIService.shared

        // Create a test character
        testCharacter = Character(
            name: "Test Assistant",
            masterPrompt: "You are a helpful test assistant.",
            avatarAsset: "person"
        )
    }

    override func tearDown() {
        testCharacter = nil
        aiService = nil
        super.tearDown()
    }

    // MARK: - Basic Context Building Tests

    func testBuildContextMessagesBasic() {
        let messages = aiService.buildContextMessages(
            for: testCharacter,
            userMessage: "Hello, how are you?",
            messageHistoryCount: 10
        )

        // Should have system message + user message
        XCTAssertGreaterThanOrEqual(messages.count, 2)

        // First message should be system
        XCTAssertEqual(messages.first?.role, "system")
        XCTAssertTrue(messages.first?.content.contains(testCharacter.masterPrompt) == true)

        // Last message should be user message
        XCTAssertEqual(messages.last?.role, "user")
        XCTAssertEqual(messages.last?.content, "Hello, how are you?")
    }

    func testSystemPromptContainsInstructions() {
        let messages = aiService.buildContextMessages(
            for: testCharacter,
            userMessage: "Test",
            messageHistoryCount: 10
        )

        guard let systemMessage = messages.first else {
            XCTFail("No system message found")
            return
        }

        // Should contain master prompt
        XCTAssertTrue(systemMessage.content.contains(testCharacter.masterPrompt))

        // Should contain context instructions
        XCTAssertTrue(systemMessage.content.contains("CONTEXT"))

        // Should contain suggested replies instructions
        XCTAssertTrue(systemMessage.content.contains("SUGGESTED QUICK REPLIES"))
        XCTAssertTrue(systemMessage.content.contains("[SUGGESTIONS:"))
    }

    func testEmptyUserMessage() {
        let messages = aiService.buildContextMessages(
            for: testCharacter,
            userMessage: "",
            messageHistoryCount: 10
        )

        // Should still build valid context
        XCTAssertGreaterThanOrEqual(messages.count, 2)

        // Last message should be empty user message
        XCTAssertEqual(messages.last?.role, "user")
        XCTAssertEqual(messages.last?.content, "")
    }

    // MARK: - Persistent Context Tests

    func testPersistentContextInjection() {
        var character = testCharacter!
        character.persistentContext = "The user likes morning coffee and enjoys hiking."

        let messages = aiService.buildContextMessages(
            for: character,
            userMessage: "What should I do today?",
            messageHistoryCount: 10
        )

        // Should contain an assistant message with context
        let assistantMessages = messages.filter { $0.role == "assistant" }
        XCTAssertGreaterThan(assistantMessages.count, 0)

        // Should contain persistent context
        let hasContext = assistantMessages.contains { $0.content.contains("likes morning coffee") }
        XCTAssertTrue(hasContext)
    }

    func testEmptyPersistentContext() {
        var character = testCharacter!
        character.persistentContext = ""

        let messages = aiService.buildContextMessages(
            for: character,
            userMessage: "Hello",
            messageHistoryCount: 10
        )

        // Should not inject empty context assistant message
        let assistantContextMessages = messages.filter {
            $0.role == "assistant" && $0.content.contains("Here's what I know")
        }
        XCTAssertEqual(assistantContextMessages.count, 0)
    }

    // MARK: - Chat History Tests

    func testChatHistoryIncluded() {
        var character = testCharacter!
        character.chatHistory = [
            Message(role: "user", content: "Message 1"),
            Message(role: "assistant", content: "Response 1"),
            Message(role: "user", content: "Message 2"),
            Message(role: "assistant", content: "Response 2")
        ]

        let messages = aiService.buildContextMessages(
            for: character,
            userMessage: "Message 3",
            messageHistoryCount: 10
        )

        // Should include all history messages
        let historyUserMessages = messages.filter {
            $0.role == "user" && ($0.content == "Message 1" || $0.content == "Message 2")
        }
        XCTAssertEqual(historyUserMessages.count, 2)

        let historyAssistantMessages = messages.filter {
            $0.role == "assistant" && ($0.content == "Response 1" || $0.content == "Response 2")
        }
        XCTAssertEqual(historyAssistantMessages.count, 2)
    }

    func testChatHistoryTruncation() {
        var character = testCharacter!

        // Add 20 messages
        for i in 0..<20 {
            character.chatHistory.append(Message(role: i % 2 == 0 ? "user" : "assistant", content: "Message \(i)"))
        }

        // Request only last 5 messages
        let messages = aiService.buildContextMessages(
            for: character,
            userMessage: "New message",
            messageHistoryCount: 5
        )

        // Count history messages (excluding system, context assistant, and new user message)
        let historyMessages = messages.filter { message in
            message.content.contains("Message") &&
            !message.content.contains("New message")
        }

        // Should only include last 5 from history
        XCTAssertEqual(historyMessages.count, 5)

        // Should be the most recent ones (15-19)
        let lastHistoryMessage = historyMessages.last
        XCTAssertTrue(lastHistoryMessage?.content.contains("Message 19") == true)
    }

    func testEmptyChatHistory() {
        var character = testCharacter!
        character.chatHistory = []

        let messages = aiService.buildContextMessages(
            for: character,
            userMessage: "First message",
            messageHistoryCount: 10
        )

        // Should still build valid context
        XCTAssertGreaterThanOrEqual(messages.count, 2)

        // Should have system + user only
        XCTAssertEqual(messages.first?.role, "system")
        XCTAssertEqual(messages.last?.role, "user")
        XCTAssertEqual(messages.last?.content, "First message")
    }

    // MARK: - Habit Tracking Context Tests

    func testHabitSystemInstructionsWhenHabitsPresent() {
        var character = testCharacter!
        character.habits = [
            Habit(name: "Morning Exercise", targetDescription: "30 min workout", frequency: .daily)
        ]

        let messages = aiService.buildContextMessages(
            for: character,
            userMessage: "Hello",
            messageHistoryCount: 10
        )

        guard let systemMessage = messages.first else {
            XCTFail("No system message found")
            return
        }

        // Should contain habit tracking instructions
        XCTAssertTrue(systemMessage.content.contains("HABIT TRACKING SYSTEM"))
        XCTAssertTrue(systemMessage.content.contains("[HABIT_COMPLETE:"))
        XCTAssertTrue(systemMessage.content.contains("[HABIT_SKIP:"))
    }

    func testNoHabitInstructionsWhenNoHabits() {
        var character = testCharacter!
        character.habits = []

        let messages = aiService.buildContextMessages(
            for: character,
            userMessage: "Hello",
            messageHistoryCount: 10
        )

        guard let systemMessage = messages.first else {
            XCTFail("No system message found")
            return
        }

        // Should NOT contain habit tracking instructions
        XCTAssertFalse(systemMessage.content.contains("HABIT TRACKING SYSTEM"))
    }

    func testHabitStatusInjection() {
        var character = testCharacter!
        character.habits = [
            Habit(name: "Morning Exercise", targetDescription: "30 min workout", frequency: .daily)
        ]

        let messages = aiService.buildContextMessages(
            for: character,
            userMessage: "How am I doing?",
            messageHistoryCount: 10
        )

        // Should have assistant message with habit status
        let assistantMessages = messages.filter { $0.role == "assistant" }
        XCTAssertGreaterThan(assistantMessages.count, 0)

        // Should contain habit tracking status
        let hasHabitStatus = assistantMessages.contains {
            $0.content.contains("HABIT TRACKING STATUS") &&
            $0.content.contains("Morning Exercise")
        }
        XCTAssertTrue(hasHabitStatus)
    }

    func testDisabledHabitsNotIncluded() {
        var character = testCharacter!
        var habit1 = Habit(name: "Exercise", targetDescription: "30 min", frequency: .daily)
        var habit2 = Habit(name: "Reading", targetDescription: "20 min", frequency: .daily)
        habit2.isEnabled = false

        character.habits = [habit1, habit2]

        let messages = aiService.buildContextMessages(
            for: character,
            userMessage: "Hello",
            messageHistoryCount: 10
        )

        // Should only include enabled habit
        let assistantMessages = messages.filter { $0.role == "assistant" }
        let habitContext = assistantMessages.first { $0.content.contains("HABIT TRACKING STATUS") }

        if let context = habitContext {
            XCTAssertTrue(context.content.contains("Exercise"))
            XCTAssertFalse(context.content.contains("Reading"))
        }
    }

    // MARK: - Reminder Context Tests

    func testReminderContextInjection() {
        let messages = aiService.buildContextMessages(
            for: testCharacter,
            userMessage: "",
            reminderContext: "Daily check-in at 9 AM",
            messageHistoryCount: 10
        )

        // Last message should contain reminder trigger
        guard let lastMessage = messages.last else {
            XCTFail("No messages found")
            return
        }

        XCTAssertEqual(lastMessage.role, "user")
        XCTAssertTrue(lastMessage.content.contains("[REMINDER TRIGGERED:"))
        XCTAssertTrue(lastMessage.content.contains("Daily check-in at 9 AM"))
    }

    func testReminderWithUserMessage() {
        let messages = aiService.buildContextMessages(
            for: testCharacter,
            userMessage: "I'm doing great today!",
            reminderContext: "Daily check-in",
            messageHistoryCount: 10
        )

        guard let lastMessage = messages.last else {
            XCTFail("No messages found")
            return
        }

        XCTAssertEqual(lastMessage.role, "user")
        XCTAssertTrue(lastMessage.content.contains("[REMINDER:"))
        XCTAssertTrue(lastMessage.content.contains("I'm doing great today!"))
    }

    func testNoReminderContext() {
        let messages = aiService.buildContextMessages(
            for: testCharacter,
            userMessage: "Hello",
            reminderContext: nil,
            messageHistoryCount: 10
        )

        // Should not contain reminder markers
        guard let lastMessage = messages.last else {
            XCTFail("No messages found")
            return
        }

        XCTAssertFalse(lastMessage.content.contains("[REMINDER"))
        XCTAssertEqual(lastMessage.content, "Hello")
    }

    // MARK: - Message Count Tests

    func testMessageCountWithAllComponents() {
        var character = testCharacter!
        character.persistentContext = "User likes coffee"
        character.habits = [
            Habit(name: "Exercise", targetDescription: "30 min", frequency: .daily)
        ]
        character.chatHistory = [
            Message(role: "user", content: "Previous message"),
            Message(role: "assistant", content: "Previous response")
        ]

        let messages = aiService.buildContextMessages(
            for: character,
            userMessage: "New message",
            messageHistoryCount: 10
        )

        // Should have:
        // 1. System message
        // 2. Assistant message (persistent context + habit status)
        // 3. Previous user message
        // 4. Previous assistant response
        // 5. New user message
        XCTAssertEqual(messages.count, 5)

        // Verify order
        XCTAssertEqual(messages[0].role, "system")
        XCTAssertEqual(messages[1].role, "assistant")
        XCTAssertEqual(messages[2].role, "user")
        XCTAssertEqual(messages[3].role, "assistant")
        XCTAssertEqual(messages[4].role, "user")
    }

    func testMessageCountMinimal() {
        var character = testCharacter!
        character.persistentContext = ""
        character.habits = []
        character.chatHistory = []

        let messages = aiService.buildContextMessages(
            for: character,
            userMessage: "Hello",
            messageHistoryCount: 10
        )

        // Should have only:
        // 1. System message
        // 2. User message
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].role, "system")
        XCTAssertEqual(messages[1].role, "user")
    }
}
