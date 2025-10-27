//
//  StorageServiceTests.swift
//  WigiAITests
//
//  Tests for StorageService data persistence and integrity
//
//  ✅ These tests use a temporary directory - production data is never touched!
//

import XCTest
@testable import WigiAI

final class StorageServiceTests: XCTestCase {
    var storageService: StorageService!
    var testCharacter: Character!
    var testDirectory: URL!

    override func setUp() {
        super.setUp()

        // Create a unique temporary directory for this test
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WigiAITests")
            .appendingPathComponent(UUID().uuidString)

        // Initialize StorageService with test directory
        storageService = StorageService(customDirectory: testDirectory)

        // Create a test character
        testCharacter = Character(
            name: "Test Character",
            masterPrompt: "You are a test assistant",
            avatarAsset: "person",
            position: CGPoint(x: 100, y: 100)
        )
    }

    override func tearDown() {
        // Clean up the entire test directory
        if let testDirectory = testDirectory {
            try? FileManager.default.removeItem(at: testDirectory)
        }

        testCharacter = nil
        storageService = nil
        testDirectory = nil
        super.tearDown()
    }

    // MARK: - Settings Tests

    func testLoadDefaultSettings() {
        let settings = storageService.loadSettings()

        XCTAssertNotNil(settings)
        XCTAssertEqual(settings.messageHistoryCount, 10)
        XCTAssertFalse(settings.hasCompletedOnboarding)
        XCTAssertTrue(settings.autoUpdateEnabled)
    }

    func testSaveAndLoadSettings() {
        var settings = storageService.loadSettings()
        settings.hasCompletedOnboarding = true
        settings.messageHistoryCount = 20
        settings.autoUpdateEnabled = false

        let result = storageService.saveSettings(settings)

        switch result {
        case .success:
            let loadedSettings = storageService.loadSettings()
            XCTAssertTrue(loadedSettings.hasCompletedOnboarding)
            XCTAssertEqual(loadedSettings.messageHistoryCount, 20)
            XCTAssertFalse(loadedSettings.autoUpdateEnabled)
        case .failure(let error):
            XCTFail("Failed to save settings: \(error)")
        }
    }

    func testSettingsWithCharacterIDs() {
        var settings = storageService.loadSettings()
        let uuid1 = UUID()
        let uuid2 = UUID()
        settings.characterIds = [uuid1, uuid2]

        let result = storageService.saveSettings(settings)

        switch result {
        case .success:
            let loadedSettings = storageService.loadSettings()
            XCTAssertEqual(loadedSettings.characterIds.count, 2)
            XCTAssertTrue(loadedSettings.characterIds.contains(uuid1))
            XCTAssertTrue(loadedSettings.characterIds.contains(uuid2))
        case .failure(let error):
            XCTFail("Failed to save settings with character IDs: \(error)")
        }
    }

    // MARK: - Character Save/Load Tests

    func testSaveAndLoadCharacter() {
        let result = storageService.saveCharacter(testCharacter)

        switch result {
        case .success:
            if let loadedCharacter = storageService.loadCharacter(id: testCharacter.id) {
                XCTAssertEqual(loadedCharacter.id, testCharacter.id)
                XCTAssertEqual(loadedCharacter.name, testCharacter.name)
                XCTAssertEqual(loadedCharacter.masterPrompt, testCharacter.masterPrompt)
                XCTAssertEqual(loadedCharacter.avatarAsset, testCharacter.avatarAsset)
            } else {
                XCTFail("Failed to load saved character")
            }
        case .failure(let error):
            XCTFail("Failed to save character: \(error)")
        }
    }

    func testLoadNonexistentCharacter() {
        let randomUUID = UUID()
        let character = storageService.loadCharacter(id: randomUUID)

        XCTAssertNil(character, "Loading nonexistent character should return nil")
    }

    func testUpdateCharacter() {
        // Save initial character
        var settings = storageService.loadSettings()
        _ = storageService.saveCharacter(testCharacter)

        // Modify and update
        var updatedCharacter = testCharacter!
        updatedCharacter.name = "Updated Name"
        updatedCharacter.masterPrompt = "Updated prompt"

        let result = storageService.updateCharacter(updatedCharacter, in: &settings)

        switch result {
        case .success:
            if let loadedCharacter = storageService.loadCharacter(id: testCharacter.id) {
                XCTAssertEqual(loadedCharacter.name, "Updated Name")
                XCTAssertEqual(loadedCharacter.masterPrompt, "Updated prompt")
            } else {
                XCTFail("Failed to load updated character")
            }
        case .failure(let error):
            XCTFail("Failed to update character: \(error)")
        }
    }

    func testSaveCharacterWithMessages() {
        var character = testCharacter!
        character.chatHistory = [
            Message(role: "user", content: "Hello"),
            Message(role: "assistant", content: "Hi there!")
        ]

        let result = storageService.saveCharacter(character)

        switch result {
        case .success:
            if let loadedCharacter = storageService.loadCharacter(id: character.id) {
                XCTAssertEqual(loadedCharacter.chatHistory.count, 2)
                XCTAssertEqual(loadedCharacter.chatHistory[0].content, "Hello")
                XCTAssertEqual(loadedCharacter.chatHistory[1].content, "Hi there!")
            } else {
                XCTFail("Failed to load character with messages")
            }
        case .failure(let error):
            XCTFail("Failed to save character with messages: \(error)")
        }
    }

    func testSaveCharacterWithHabits() {
        var character = testCharacter!
        character.habits = [
            Habit(
                name: "Morning Routine",
                targetDescription: "Complete morning routine",
                frequency: .daily
            ),
            Habit(
                name: "Exercise",
                targetDescription: "30 minutes of exercise",
                frequency: .weekdays
            )
        ]

        let result = storageService.saveCharacter(character)

        switch result {
        case .success:
            if let loadedCharacter = storageService.loadCharacter(id: character.id) {
                XCTAssertEqual(loadedCharacter.habits.count, 2)
                XCTAssertEqual(loadedCharacter.habits[0].name, "Morning Routine")
                XCTAssertEqual(loadedCharacter.habits[1].name, "Exercise")
                XCTAssertEqual(loadedCharacter.habits[0].frequency, .daily)
                XCTAssertEqual(loadedCharacter.habits[1].frequency, .weekdays)
            } else {
                XCTFail("Failed to load character with habits")
            }
        case .failure(let error):
            XCTFail("Failed to save character with habits: \(error)")
        }
    }

    func testSaveCharacterWithReminders() {
        var character = testCharacter!
        character.reminders = [
            Reminder(time: Date(), reminderText: "Check in", isEnabled: true)
        ]

        let result = storageService.saveCharacter(character)

        switch result {
        case .success:
            if let loadedCharacter = storageService.loadCharacter(id: character.id) {
                XCTAssertEqual(loadedCharacter.reminders.count, 1)
                XCTAssertEqual(loadedCharacter.reminders[0].reminderText, "Check in")
                XCTAssertTrue(loadedCharacter.reminders[0].isEnabled)
            } else {
                XCTFail("Failed to load character with reminders")
            }
        case .failure(let error):
            XCTFail("Failed to save character with reminders: \(error)")
        }
    }

    // MARK: - Character Collection Tests

    func testLoadAllCharacters() {
        // Save multiple characters
        let char1 = Character(name: "Character 1", masterPrompt: "Prompt 1", avatarAsset: "person")
        let char2 = Character(name: "Character 2", masterPrompt: "Prompt 2", avatarAsset: "professional")

        _ = storageService.saveCharacter(char1)
        _ = storageService.saveCharacter(char2)

        // Update settings with character IDs
        var settings = storageService.loadSettings()
        settings.characterIds = [char1.id, char2.id]
        _ = storageService.saveSettings(settings)

        // Load all characters
        let characters = storageService.loadCharacters(for: settings)

        XCTAssertGreaterThanOrEqual(characters.count, 2)
        XCTAssertTrue(characters.contains { $0.id == char1.id })
        XCTAssertTrue(characters.contains { $0.id == char2.id })
    }

    func testDeleteCharacter() {
        // Save character
        var settings = storageService.loadSettings()
        _ = storageService.saveCharacter(testCharacter)

        // Verify it exists
        XCTAssertNotNil(storageService.loadCharacter(id: testCharacter.id))

        // Delete it
        storageService.deleteCharacter(id: testCharacter.id, from: &settings)

        // Verify it's gone
        XCTAssertNil(storageService.loadCharacter(id: testCharacter.id))
    }

    func testDeleteNonexistentCharacter() {
        let randomUUID = UUID()
        var settings = storageService.loadSettings()

        // Should succeed (idempotent operation)
        storageService.deleteCharacter(id: randomUUID, from: &settings)

        // Verify it doesn't exist
        XCTAssertNil(storageService.loadCharacter(id: randomUUID))
    }

    // MARK: - Persistence Context Tests

    func testSavePersistentContext() {
        var character = testCharacter!
        character.persistentContext = "This is a persistent context summary"

        let result = storageService.saveCharacter(character)

        switch result {
        case .success:
            if let loadedCharacter = storageService.loadCharacter(id: character.id) {
                XCTAssertEqual(loadedCharacter.persistentContext, "This is a persistent context summary")
            } else {
                XCTFail("Failed to load character with persistent context")
            }
        case .failure(let error):
            XCTFail("Failed to save character with persistent context: \(error)")
        }
    }

    func testSaveEmptyPersistentContext() {
        var character = testCharacter!
        character.persistentContext = ""

        let result = storageService.saveCharacter(character)

        switch result {
        case .success:
            if let loadedCharacter = storageService.loadCharacter(id: character.id) {
                XCTAssertEqual(loadedCharacter.persistentContext, "")
            } else {
                XCTFail("Failed to load character with empty persistent context")
            }
        case .failure(let error):
            XCTFail("Failed to save character with empty persistent context: \(error)")
        }
    }

    // MARK: - Large Data Tests

    func testSaveCharacterWithLargeHistory() {
        var character = testCharacter!

        // Create 100 messages
        for i in 0..<100 {
            character.chatHistory.append(Message(role: i % 2 == 0 ? "user" : "assistant", content: "Message \(i)"))
        }

        let result = storageService.saveCharacter(character)

        switch result {
        case .success:
            if let loadedCharacter = storageService.loadCharacter(id: character.id) {
                XCTAssertEqual(loadedCharacter.chatHistory.count, 100)
                XCTAssertEqual(loadedCharacter.chatHistory.first?.content, "Message 0")
                XCTAssertEqual(loadedCharacter.chatHistory.last?.content, "Message 99")
            } else {
                XCTFail("Failed to load character with large history")
            }
        case .failure(let error):
            XCTFail("Failed to save character with large history: \(error)")
        }
    }
}
