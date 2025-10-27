//
//  CharacterTemplateTests.swift
//  WigiAITests
//
//  Unit tests for CharacterTemplate conversion and CharacterTemplateService
//

import XCTest
@testable import WigiAI

final class CharacterTemplateTests: XCTestCase {

    // MARK: - CharacterTemplate.toCharacter() Tests

    func testToCharacter_BasicConversion() {
        // Test basic template to character conversion
        let template = CharacterTemplate(
            id: "test-character",
            name: "Test Character",
            category: "Testing",
            description: "A test character",
            avatar: "person",
            masterPrompt: "You are a helpful test character.",
            habits: [],
            reminders: []
        )

        let character = template.toCharacter()

        XCTAssertEqual(character.name, "Test Character")
        XCTAssertEqual(character.masterPrompt, "You are a helpful test character.")
        XCTAssertEqual(character.avatarAsset, "person")
        XCTAssertTrue(character.habits.isEmpty)
        XCTAssertTrue(character.reminders.isEmpty)
    }

    func testToCharacter_DailyHabit() {
        // Test daily habit conversion
        let habitTemplate = CharacterTemplate.HabitTemplate(
            name: "Exercise",
            targetDescription: "30 minutes of cardio",
            frequency: "daily",
            customDays: nil,
            reminderTime: nil
        )

        let template = CharacterTemplate(
            id: "test",
            name: "Test",
            category: "Test",
            description: "Test",
            avatar: "person",
            masterPrompt: "Test",
            habits: [habitTemplate],
            reminders: []
        )

        let character = template.toCharacter()

        XCTAssertEqual(character.habits.count, 1)
        let habit = character.habits[0]
        XCTAssertEqual(habit.name, "Exercise")
        XCTAssertEqual(habit.targetDescription, "30 minutes of cardio")
        XCTAssertEqual(habit.frequency, .daily)
        XCTAssertNil(habit.customDays)
    }

    func testToCharacter_WeekdaysHabit() {
        // Test weekdays habit conversion
        let habitTemplate = CharacterTemplate.HabitTemplate(
            name: "Work Task",
            targetDescription: "Complete daily standup",
            frequency: "weekdays",
            customDays: nil,
            reminderTime: nil
        )

        let template = CharacterTemplate(
            id: "test",
            name: "Test",
            category: "Test",
            description: "Test",
            avatar: "person",
            masterPrompt: "Test",
            habits: [habitTemplate],
            reminders: []
        )

        let character = template.toCharacter()

        XCTAssertEqual(character.habits.count, 1)
        XCTAssertEqual(character.habits[0].frequency, .weekdays)
    }

    func testToCharacter_WeekendsHabit() {
        // Test weekends habit conversion
        let habitTemplate = CharacterTemplate.HabitTemplate(
            name: "Relax",
            targetDescription: "Take time to unwind",
            frequency: "weekends",
            customDays: nil,
            reminderTime: nil
        )

        let template = CharacterTemplate(
            id: "test",
            name: "Test",
            category: "Test",
            description: "Test",
            avatar: "person",
            masterPrompt: "Test",
            habits: [habitTemplate],
            reminders: []
        )

        let character = template.toCharacter()

        XCTAssertEqual(character.habits.count, 1)
        XCTAssertEqual(character.habits[0].frequency, .weekends)
    }

    func testToCharacter_CustomDaysHabit() {
        // Test custom days habit conversion
        let habitTemplate = CharacterTemplate.HabitTemplate(
            name: "Workout",
            targetDescription: "Gym session",
            frequency: "custom",
            customDays: [2, 4, 6],  // Monday, Wednesday, Friday
            reminderTime: nil
        )

        let template = CharacterTemplate(
            id: "test",
            name: "Test",
            category: "Test",
            description: "Test",
            avatar: "person",
            masterPrompt: "Test",
            habits: [habitTemplate],
            reminders: []
        )

        let character = template.toCharacter()

        XCTAssertEqual(character.habits.count, 1)
        let habit = character.habits[0]
        XCTAssertEqual(habit.frequency, .custom)
        XCTAssertNotNil(habit.customDays)
        XCTAssertEqual(habit.customDays, [2, 4, 6])
    }

    func testToCharacter_InvalidFrequencyDefaultsToDaily() {
        // Test that invalid frequency defaults to daily
        let habitTemplate = CharacterTemplate.HabitTemplate(
            name: "Test",
            targetDescription: "Test",
            frequency: "invalid",
            customDays: nil,
            reminderTime: nil
        )

        let template = CharacterTemplate(
            id: "test",
            name: "Test",
            category: "Test",
            description: "Test",
            avatar: "person",
            masterPrompt: "Test",
            habits: [habitTemplate],
            reminders: []
        )

        let character = template.toCharacter()

        XCTAssertEqual(character.habits[0].frequency, .daily, "Invalid frequency should default to daily")
    }

    func testToCharacter_HabitWithReminderTime() {
        // Test habit with reminder time creates linked reminder
        let habitTemplate = CharacterTemplate.HabitTemplate(
            name: "Morning Meditation",
            targetDescription: "10 minutes of meditation",
            frequency: "daily",
            customDays: nil,
            reminderTime: "08:00"
        )

        let template = CharacterTemplate(
            id: "test",
            name: "Test",
            category: "Test",
            description: "Test",
            avatar: "person",
            masterPrompt: "Test",
            habits: [habitTemplate],
            reminders: []
        )

        let character = template.toCharacter()

        XCTAssertEqual(character.habits.count, 1)
        let habit = character.habits[0]
        XCTAssertNotNil(habit.reminderTime, "Habit should have reminder time")

        // Should create a linked reminder
        XCTAssertEqual(character.reminders.count, 1, "Should create linked reminder for habit")
        let linkedReminder = character.reminders[0]
        XCTAssertEqual(linkedReminder.linkedHabitId, habit.id, "Reminder should be linked to habit")
        XCTAssertTrue(linkedReminder.reminderText.contains("Time to check in!"))
    }

    func testToCharacter_ReminderConversion() {
        // Test basic reminder conversion
        let reminderTemplate = CharacterTemplate.ReminderTemplate(
            time: "09:00",
            reminderText: "Morning check-in"
        )

        let template = CharacterTemplate(
            id: "test",
            name: "Test",
            category: "Test",
            description: "Test",
            avatar: "person",
            masterPrompt: "Test",
            habits: [],
            reminders: [reminderTemplate]
        )

        let character = template.toCharacter()

        XCTAssertEqual(character.reminders.count, 1)
        let reminder = character.reminders[0]
        XCTAssertEqual(reminder.reminderText, "Morning check-in")
        XCTAssertTrue(reminder.isEnabled)
        XCTAssertNil(reminder.linkedHabitId, "Regular reminder should not be linked to habit")
    }

    func testToCharacter_ReminderTimeFormat() {
        // Test that reminder time is parsed correctly
        let reminderTemplate = CharacterTemplate.ReminderTemplate(
            time: "14:30",
            reminderText: "Afternoon reminder"
        )

        let template = CharacterTemplate(
            id: "test",
            name: "Test",
            category: "Test",
            description: "Test",
            avatar: "person",
            masterPrompt: "Test",
            habits: [],
            reminders: [reminderTemplate]
        )

        let character = template.toCharacter()

        let reminder = character.reminders[0]
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: reminder.time)

        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 30)
    }

    func testToCharacter_MultipleHabitsAndReminders() {
        // Test template with multiple habits and reminders
        let habits = [
            CharacterTemplate.HabitTemplate(
                name: "Exercise",
                targetDescription: "30 min workout",
                frequency: "daily",
                customDays: nil,
                reminderTime: "07:00"
            ),
            CharacterTemplate.HabitTemplate(
                name: "Reading",
                targetDescription: "Read 20 pages",
                frequency: "weekdays",
                customDays: nil,
                reminderTime: nil
            )
        ]

        let reminders = [
            CharacterTemplate.ReminderTemplate(
                time: "09:00",
                reminderText: "Morning check-in"
            ),
            CharacterTemplate.ReminderTemplate(
                time: "17:00",
                reminderText: "Evening reflection"
            )
        ]

        let template = CharacterTemplate(
            id: "test",
            name: "Test",
            category: "Test",
            description: "Test",
            avatar: "person",
            masterPrompt: "Test",
            habits: habits,
            reminders: reminders
        )

        let character = template.toCharacter()

        XCTAssertEqual(character.habits.count, 2)
        // 2 regular reminders + 1 linked reminder for Exercise habit
        XCTAssertEqual(character.reminders.count, 3)

        // Verify linked reminder exists
        let linkedReminders = character.reminders.filter { $0.linkedHabitId != nil }
        XCTAssertEqual(linkedReminders.count, 1, "Should have 1 linked habit reminder")
    }

    func testToCharacter_InvalidReminderTimeDefaultsToNow() {
        // Test that invalid reminder time format doesn't crash
        let reminderTemplate = CharacterTemplate.ReminderTemplate(
            time: "invalid-time",
            reminderText: "Test"
        )

        let template = CharacterTemplate(
            id: "test",
            name: "Test",
            category: "Test",
            description: "Test",
            avatar: "person",
            masterPrompt: "Test",
            habits: [],
            reminders: [reminderTemplate]
        )

        let character = template.toCharacter()

        XCTAssertEqual(character.reminders.count, 1, "Should still create reminder despite invalid time")
        // Note: Invalid time defaults to Date(), so we can't test exact value
    }

    // MARK: - CharacterTemplateService Tests

    func testCharacterTemplateService_Singleton() {
        // Test that service is a singleton
        let service1 = CharacterTemplateService.shared
        let service2 = CharacterTemplateService.shared

        XCTAssertTrue(service1 === service2, "Should return same instance")
    }

    func testCharacterTemplateService_GetAllTemplates() {
        // Test getting all templates
        let service = CharacterTemplateService.shared
        let templates = service.getAllTemplates()

        // Should have loaded templates from bundle
        XCTAssertGreaterThan(templates.count, 0, "Should load templates from bundle")
    }

    func testCharacterTemplateService_GetCategories() {
        // Test getting unique categories
        let service = CharacterTemplateService.shared
        let categories = service.getCategories()

        XCTAssertGreaterThan(categories.count, 0, "Should have at least one category")
        // Categories should be unique and sorted
        let uniqueCategories = Array(Set(categories))
        XCTAssertEqual(categories.count, uniqueCategories.count, "Categories should be unique")
        XCTAssertEqual(categories, categories.sorted(), "Categories should be sorted")
    }

    func testCharacterTemplateService_GetTemplatesForCategory() {
        // Test filtering by category
        let service = CharacterTemplateService.shared
        let allTemplates = service.getAllTemplates()

        guard let firstTemplate = allTemplates.first else {
            XCTFail("No templates loaded")
            return
        }

        let category = firstTemplate.category
        let templatesInCategory = service.getTemplates(for: category)

        XCTAssertGreaterThan(templatesInCategory.count, 0, "Should find templates in category")
        XCTAssertTrue(templatesInCategory.allSatisfy { $0.category == category }, "All templates should be in specified category")
    }

    func testCharacterTemplateService_GetTemplatesForNonexistentCategory() {
        // Test filtering by nonexistent category
        let service = CharacterTemplateService.shared
        let templates = service.getTemplates(for: "NonexistentCategory12345")

        XCTAssertTrue(templates.isEmpty, "Should return empty array for nonexistent category")
    }

    func testCharacterTemplateService_GetTemplateById() {
        // Test getting template by ID
        let service = CharacterTemplateService.shared
        let allTemplates = service.getAllTemplates()

        guard let firstTemplate = allTemplates.first else {
            XCTFail("No templates loaded")
            return
        }

        let found = service.getTemplate(byId: firstTemplate.id)

        XCTAssertNotNil(found, "Should find template by ID")
        XCTAssertEqual(found?.id, firstTemplate.id)
        XCTAssertEqual(found?.name, firstTemplate.name)
    }

    func testCharacterTemplateService_GetTemplateByInvalidId() {
        // Test getting template with invalid ID
        let service = CharacterTemplateService.shared
        let found = service.getTemplate(byId: "invalid-id-12345")

        XCTAssertNil(found, "Should return nil for invalid ID")
    }

    func testCharacterTemplateService_SearchByName() {
        // Test searching templates by name
        let service = CharacterTemplateService.shared
        let allTemplates = service.getAllTemplates()

        guard let firstTemplate = allTemplates.first else {
            XCTFail("No templates loaded")
            return
        }

        // Search for first few characters of name
        let searchQuery = String(firstTemplate.name.prefix(5))
        let results = service.searchTemplates(query: searchQuery)

        XCTAssertGreaterThan(results.count, 0, "Should find templates matching name")
        XCTAssertTrue(results.contains { $0.name.lowercased().contains(searchQuery.lowercased()) })
    }

    func testCharacterTemplateService_SearchByDescription() {
        // Test searching templates by description
        let service = CharacterTemplateService.shared
        let allTemplates = service.getAllTemplates()

        guard let firstTemplate = allTemplates.first else {
            XCTFail("No templates loaded")
            return
        }

        // Search for word from description
        let words = firstTemplate.description.split(separator: " ")
        guard let searchWord = words.first else {
            XCTFail("Template has no description words")
            return
        }

        let results = service.searchTemplates(query: String(searchWord))

        XCTAssertGreaterThan(results.count, 0, "Should find templates matching description")
    }

    func testCharacterTemplateService_SearchCaseInsensitive() {
        // Test that search is case-insensitive
        let service = CharacterTemplateService.shared
        let allTemplates = service.getAllTemplates()

        guard let firstTemplate = allTemplates.first else {
            XCTFail("No templates loaded")
            return
        }

        let searchQuery = String(firstTemplate.name.prefix(5))
        let resultsLowercase = service.searchTemplates(query: searchQuery.lowercased())
        let resultsUppercase = service.searchTemplates(query: searchQuery.uppercased())

        XCTAssertEqual(resultsLowercase.count, resultsUppercase.count, "Search should be case-insensitive")
    }

    func testCharacterTemplateService_SearchNoMatch() {
        // Test searching with query that matches nothing
        let service = CharacterTemplateService.shared
        let results = service.searchTemplates(query: "xyzabc123nonexistent")

        XCTAssertTrue(results.isEmpty, "Should return empty array for no matches")
    }

    func testCharacterTemplateService_CreateCharacterFromTemplate() {
        // Test creating character from template
        let service = CharacterTemplateService.shared
        let allTemplates = service.getAllTemplates()

        guard let firstTemplate = allTemplates.first else {
            XCTFail("No templates loaded")
            return
        }

        let character = service.createCharacter(from: firstTemplate)

        XCTAssertEqual(character.name, firstTemplate.name)
        XCTAssertEqual(character.masterPrompt, firstTemplate.masterPrompt)
        XCTAssertEqual(character.avatarAsset, firstTemplate.avatar)
    }

    func testCharacterTemplateService_TemplatesSorted() {
        // Test that templates are sorted by category then name
        let service = CharacterTemplateService.shared
        let templates = service.getAllTemplates()

        for i in 0..<(templates.count - 1) {
            let current = templates[i]
            let next = templates[i + 1]

            if current.category == next.category {
                XCTAssertLessThanOrEqual(current.name, next.name, "Templates in same category should be sorted by name")
            } else {
                XCTAssertLessThan(current.category, next.category, "Templates should be sorted by category")
            }
        }
    }
}
