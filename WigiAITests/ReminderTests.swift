//
//  ReminderTests.swift
//  WigiAITests
//
//  Unit tests for Reminder model
//

import XCTest
@testable import WigiAI

final class ReminderTests: XCTestCase {

    // MARK: - Initialization Tests

    func testReminder_DefaultInitialization() {
        // Test initialization with default values
        let time = Date()
        let reminder = Reminder(time: time, reminderText: "Test reminder")

        XCTAssertNotNil(reminder.id)
        XCTAssertEqual(reminder.time, time)
        XCTAssertEqual(reminder.reminderText, "Test reminder")
        XCTAssertTrue(reminder.isEnabled, "Should default to enabled")
        XCTAssertNil(reminder.lastTriggered)
        XCTAssertNil(reminder.linkedHabitId)
    }

    func testReminder_CustomInitialization() {
        // Test initialization with all custom values
        let id = UUID()
        let time = Date()
        let lastTriggered = Date(timeIntervalSinceNow: -3600)
        let habitId = UUID()

        let reminder = Reminder(
            id: id,
            time: time,
            reminderText: "Custom reminder",
            isEnabled: false,
            lastTriggered: lastTriggered,
            linkedHabitId: habitId
        )

        XCTAssertEqual(reminder.id, id)
        XCTAssertEqual(reminder.time, time)
        XCTAssertEqual(reminder.reminderText, "Custom reminder")
        XCTAssertFalse(reminder.isEnabled)
        XCTAssertEqual(reminder.lastTriggered, lastTriggered)
        XCTAssertEqual(reminder.linkedHabitId, habitId)
    }

    // MARK: - Enabled State Tests

    func testReminder_EnabledByDefault() {
        // Test that reminders are enabled by default
        let reminder = Reminder(time: Date(), reminderText: "Test")

        XCTAssertTrue(reminder.isEnabled)
    }

    func testReminder_DisabledState() {
        // Test disabled reminder
        let reminder = Reminder(
            time: Date(),
            reminderText: "Test",
            isEnabled: false
        )

        XCTAssertFalse(reminder.isEnabled)
    }

    // MARK: - Habit Linking Tests

    func testReminder_WithoutLinkedHabit() {
        // Test reminder without linked habit
        let reminder = Reminder(time: Date(), reminderText: "Regular reminder")

        XCTAssertNil(reminder.linkedHabitId, "Regular reminder should not be linked to habit")
    }

    func testReminder_WithLinkedHabit() {
        // Test reminder linked to habit
        let habitId = UUID()
        let reminder = Reminder(
            time: Date(),
            reminderText: "Habit reminder",
            linkedHabitId: habitId
        )

        XCTAssertNotNil(reminder.linkedHabitId)
        XCTAssertEqual(reminder.linkedHabitId, habitId)
    }

    // MARK: - Last Triggered Tests

    func testReminder_NeverTriggered() {
        // Test reminder that has never been triggered
        let reminder = Reminder(time: Date(), reminderText: "Test")

        XCTAssertNil(reminder.lastTriggered)
    }

    func testReminder_WithLastTriggered() {
        // Test reminder with last triggered time
        let triggeredTime = Date(timeIntervalSinceNow: -3600)
        let reminder = Reminder(
            time: Date(),
            reminderText: "Test",
            lastTriggered: triggeredTime
        )

        XCTAssertNotNil(reminder.lastTriggered)
        XCTAssertEqual(reminder.lastTriggered, triggeredTime)
    }

    // MARK: - Time Tests

    func testReminder_TimeOfDay() {
        // Test reminder time
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 9
        components.minute = 30
        let time = calendar.date(from: components)!

        let reminder = Reminder(time: time, reminderText: "Morning reminder")

        let timeComponents = calendar.dateComponents([.hour, .minute], from: reminder.time)
        XCTAssertEqual(timeComponents.hour, 9)
        XCTAssertEqual(timeComponents.minute, 30)
    }

    func testReminder_MidnightTime() {
        // Test reminder at midnight
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 0
        components.minute = 0
        let time = calendar.date(from: components)!

        let reminder = Reminder(time: time, reminderText: "Midnight reminder")

        let timeComponents = calendar.dateComponents([.hour, .minute], from: reminder.time)
        XCTAssertEqual(timeComponents.hour, 0)
        XCTAssertEqual(timeComponents.minute, 0)
    }

    func testReminder_EndOfDayTime() {
        // Test reminder at end of day
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 23
        components.minute = 59
        let time = calendar.date(from: components)!

        let reminder = Reminder(time: time, reminderText: "Late night reminder")

        let timeComponents = calendar.dateComponents([.hour, .minute], from: reminder.time)
        XCTAssertEqual(timeComponents.hour, 23)
        XCTAssertEqual(timeComponents.minute, 59)
    }

    // MARK: - Reminder Text Tests

    func testReminder_EmptyText() {
        // Test reminder with empty text
        let reminder = Reminder(time: Date(), reminderText: "")

        XCTAssertEqual(reminder.reminderText, "")
    }

    func testReminder_LongText() {
        // Test reminder with long text
        let longText = String(repeating: "a", count: 1000)
        let reminder = Reminder(time: Date(), reminderText: longText)

        XCTAssertEqual(reminder.reminderText.count, 1000)
    }

    func testReminder_MultilineText() {
        // Test reminder with multiline text
        let multilineText = """
        Line 1
        Line 2
        Line 3
        """
        let reminder = Reminder(time: Date(), reminderText: multilineText)

        XCTAssertEqual(reminder.reminderText, multilineText)
        XCTAssertTrue(reminder.reminderText.contains("\n"))
    }

    func testReminder_SpecialCharactersText() {
        // Test reminder with special characters
        let text = "Reminder with @#$%^&*() special chars!"
        let reminder = Reminder(time: Date(), reminderText: text)

        XCTAssertEqual(reminder.reminderText, text)
    }

    // MARK: - Encoding/Decoding Tests

    func testReminder_EncodeDecode() throws {
        // Test basic encode/decode round-trip
        let original = Reminder(
            time: Date(),
            reminderText: "Test reminder",
            isEnabled: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Reminder.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.reminderText, original.reminderText)
        XCTAssertEqual(decoded.isEnabled, original.isEnabled)
    }

    func testReminder_EncodeDecodeWithLinkedHabit() throws {
        // Test encoding/decoding with linked habit
        let habitId = UUID()
        let original = Reminder(
            time: Date(),
            reminderText: "Habit reminder",
            linkedHabitId: habitId
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Reminder.self, from: data)

        XCTAssertEqual(decoded.linkedHabitId, habitId)
    }

    func testReminder_EncodeDecodeWithLastTriggered() throws {
        // Test encoding/decoding with last triggered time
        let triggeredTime = Date(timeIntervalSinceNow: -7200)
        let original = Reminder(
            time: Date(),
            reminderText: "Test",
            lastTriggered: triggeredTime
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Reminder.self, from: data)

        XCTAssertNotNil(decoded.lastTriggered)
        if let decodedTriggered = decoded.lastTriggered {
            XCTAssertEqual(decodedTriggered.timeIntervalSince1970, triggeredTime.timeIntervalSince1970, accuracy: 0.001)
        } else {
            XCTFail("lastTriggered should not be nil")
        }
    }

    func testReminder_DecodeWithMissingLinkedHabitId() throws {
        // Test backward compatibility when linkedHabitId is missing
        let jsonString = """
        {
            "id": "\(UUID().uuidString)",
            "time": \(Date().timeIntervalSinceReferenceDate),
            "reminderText": "Test",
            "isEnabled": true
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Reminder.self, from: data)

        XCTAssertNil(decoded.linkedHabitId, "Missing linkedHabitId should decode as nil")
    }

    func testReminder_DecodeWithNullLinkedHabitId() throws {
        // Test decoding with null linkedHabitId
        let jsonString = """
        {
            "id": "\(UUID().uuidString)",
            "time": \(Date().timeIntervalSinceReferenceDate),
            "reminderText": "Test",
            "isEnabled": true,
            "linkedHabitId": null
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Reminder.self, from: data)

        XCTAssertNil(decoded.linkedHabitId)
    }

    func testReminder_DecodeWithNullLastTriggered() throws {
        // Test decoding with null lastTriggered
        let jsonString = """
        {
            "id": "\(UUID().uuidString)",
            "time": \(Date().timeIntervalSinceReferenceDate),
            "reminderText": "Test",
            "isEnabled": true,
            "lastTriggered": null
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Reminder.self, from: data)

        XCTAssertNil(decoded.lastTriggered)
    }

    // MARK: - Hashable Tests

    func testReminder_Hashable() {
        // Test that reminders are hashable
        let time = Date()
        let rem1 = Reminder(time: time, reminderText: "Reminder 1")
        let rem2 = Reminder(time: time, reminderText: "Reminder 2")
        let rem3 = Reminder(id: rem1.id, time: time, reminderText: "Reminder 1")

        var set = Set<Reminder>()
        set.insert(rem1)
        set.insert(rem2)

        XCTAssertEqual(set.count, 2)

        // Identical reminders should be considered equal
        set.insert(rem3)
        XCTAssertEqual(set.count, 2, "Reminders with identical fields should be equal")
    }

    func testReminder_Equatable() {
        // Test reminder equality (compares all fields, not just ID)
        let id = UUID()
        let time = Date()
        let rem1 = Reminder(id: id, time: time, reminderText: "Text 1")
        let rem2 = Reminder(id: id, time: time, reminderText: "Text 1")
        let rem3 = Reminder(id: id, time: time, reminderText: "Text 2")
        let rem4 = Reminder(time: time, reminderText: "Text 1")

        XCTAssertEqual(rem1, rem2, "Reminders with identical fields should be equal")
        XCTAssertNotEqual(rem1, rem3, "Reminders with different text should not be equal")
        XCTAssertNotEqual(rem1, rem4, "Reminders with different IDs should not be equal")
    }

    // MARK: - Array Operations Tests

    func testReminder_FilterEnabled() {
        // Test filtering enabled reminders
        let reminders = [
            Reminder(time: Date(), reminderText: "Enabled 1", isEnabled: true),
            Reminder(time: Date(), reminderText: "Disabled", isEnabled: false),
            Reminder(time: Date(), reminderText: "Enabled 2", isEnabled: true)
        ]

        let enabled = reminders.filter { $0.isEnabled }
        XCTAssertEqual(enabled.count, 2)
    }

    func testReminder_FilterLinkedToHabit() {
        // Test filtering reminders linked to habits
        let habitId = UUID()
        let reminders = [
            Reminder(time: Date(), reminderText: "Regular"),
            Reminder(time: Date(), reminderText: "Habit 1", linkedHabitId: habitId),
            Reminder(time: Date(), reminderText: "Habit 2", linkedHabitId: UUID())
        ]

        let habitReminders = reminders.filter { $0.linkedHabitId != nil }
        XCTAssertEqual(habitReminders.count, 2)

        let specificHabitReminders = reminders.filter { $0.linkedHabitId == habitId }
        XCTAssertEqual(specificHabitReminders.count, 1)
    }

    func testReminder_SortByTime() {
        // Test sorting reminders by time
        let calendar = Calendar.current
        let morning = calendar.date(from: DateComponents(hour: 9, minute: 0))!
        let afternoon = calendar.date(from: DateComponents(hour: 14, minute: 0))!
        let evening = calendar.date(from: DateComponents(hour: 18, minute: 0))!

        let reminders = [
            Reminder(time: afternoon, reminderText: "Second"),
            Reminder(time: morning, reminderText: "First"),
            Reminder(time: evening, reminderText: "Third")
        ]

        let sorted = reminders.sorted {
            let hour0 = calendar.dateComponents([.hour, .minute], from: $0.time).hour ?? 0
            let hour1 = calendar.dateComponents([.hour, .minute], from: $1.time).hour ?? 0
            return hour0 < hour1
        }

        XCTAssertEqual(sorted[0].reminderText, "First")
        XCTAssertEqual(sorted[1].reminderText, "Second")
        XCTAssertEqual(sorted[2].reminderText, "Third")
    }

    // MARK: - Identifiable Tests

    func testReminder_UniqueIDs() {
        // Test that each reminder gets a unique ID
        let rem1 = Reminder(time: Date(), reminderText: "Test")
        let rem2 = Reminder(time: Date(), reminderText: "Test")

        XCTAssertNotEqual(rem1.id, rem2.id, "Each reminder should have a unique ID")
    }

    func testReminder_IDPersistence() throws {
        // Test that ID persists through encoding/decoding
        let original = Reminder(time: Date(), reminderText: "Test")
        let originalID = original.id

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Reminder.self, from: data)

        XCTAssertEqual(decoded.id, originalID, "ID should persist through encoding/decoding")
    }

    // MARK: - Mutation Tests

    func testReminder_MutateIsEnabled() {
        // Test mutating enabled state
        var reminder = Reminder(time: Date(), reminderText: "Test", isEnabled: true)

        XCTAssertTrue(reminder.isEnabled)

        reminder.isEnabled = false
        XCTAssertFalse(reminder.isEnabled)
    }

    func testReminder_MutateLastTriggered() {
        // Test mutating last triggered time
        var reminder = Reminder(time: Date(), reminderText: "Test")

        XCTAssertNil(reminder.lastTriggered)

        let newTriggeredTime = Date()
        reminder.lastTriggered = newTriggeredTime
        XCTAssertEqual(reminder.lastTriggered, newTriggeredTime)
    }

    func testReminder_MutateTime() {
        // Test mutating reminder time
        var reminder = Reminder(time: Date(), reminderText: "Test")
        let originalTime = reminder.time

        let newTime = Date(timeIntervalSinceNow: 3600)
        reminder.time = newTime

        XCTAssertNotEqual(reminder.time, originalTime)
        XCTAssertEqual(reminder.time, newTime)
    }

    func testReminder_MutateReminderText() {
        // Test mutating reminder text
        var reminder = Reminder(time: Date(), reminderText: "Original")

        XCTAssertEqual(reminder.reminderText, "Original")

        reminder.reminderText = "Updated"
        XCTAssertEqual(reminder.reminderText, "Updated")
    }
}
