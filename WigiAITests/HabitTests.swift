//
//  HabitTests.swift
//  WigiAITests
//
//  Unit tests for Habit streak calculation
//

import XCTest
@testable import WigiAI

final class HabitTests: XCTestCase {

    var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar.current
    }

    override func tearDown() {
        calendar = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    /// Create a date from offset (negative = past days, 0 = today, positive = future)
    func date(daysFromToday offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: Date())!
    }

    /// Get start of day for a date
    func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Get the weekday for a date (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
    func weekday(of date: Date) -> Int {
        calendar.component(.weekday, from: date)
    }

    /// Create a habit with completion dates
    func createHabit(
        name: String = "Test Habit",
        frequency: HabitFrequency = .daily,
        customDays: Set<Int>? = nil,
        completionDates: [Date] = [],
        skipDates: [Date] = [],
        createdDate: Date? = nil
    ) -> Habit {
        Habit(
            name: name,
            targetDescription: "Test target",
            frequency: frequency,
            customDays: customDays,
            completionDates: completionDates.map { startOfDay($0) },
            skipDates: skipDates.map { startOfDay($0) },
            createdDate: createdDate ?? date(daysFromToday: -365)
        )
    }

    // MARK: - Daily Habit Tests

    func testDailyHabit_SimpleStreak() {
        // Test a simple 5-day streak ending today
        let habit = createHabit(
            frequency: .daily,
            completionDates: [
                date(daysFromToday: -4),
                date(daysFromToday: -3),
                date(daysFromToday: -2),
                date(daysFromToday: -1),
                date(daysFromToday: 0)
            ]
        )

        XCTAssertEqual(habit.currentStreak, 5, "Should have a streak of 5 days")
    }

    func testDailyHabit_StreakOverWeekend() {
        // Test that a daily habit includes weekends in the streak
        let habit = createHabit(
            frequency: .daily,
            completionDates: [
                date(daysFromToday: -6),
                date(daysFromToday: -5),
                date(daysFromToday: -4),
                date(daysFromToday: -3),
                date(daysFromToday: -2),
                date(daysFromToday: -1),
                date(daysFromToday: 0)
            ]
        )

        XCTAssertEqual(habit.currentStreak, 7, "Should have a 7-day streak including weekend")
    }

    func testDailyHabit_BrokenStreak() {
        // Test that a missing day breaks the streak
        let habit = createHabit(
            frequency: .daily,
            completionDates: [
                date(daysFromToday: -5),
                date(daysFromToday: -4),
                // Missing day -3
                date(daysFromToday: -2),
                date(daysFromToday: -1),
                date(daysFromToday: 0)
            ]
        )

        XCTAssertEqual(habit.currentStreak, 3, "Streak should be broken by missing day")
    }

    func testDailyHabit_NoCompletions() {
        // Test empty habit
        let habit = createHabit(frequency: .daily)

        XCTAssertEqual(habit.currentStreak, 0, "Empty habit should have 0 streak")
    }

    func testDailyHabit_OnlyOldCompletions() {
        // Test habit with old completions but nothing recent
        let habit = createHabit(
            frequency: .daily,
            completionDates: [
                date(daysFromToday: -10),
                date(daysFromToday: -9),
                date(daysFromToday: -8)
            ]
        )

        XCTAssertEqual(habit.currentStreak, 0, "Old completions should not count as current streak")
    }

    func testDailyHabit_StreakStartingToday() {
        // Test that completing today counts as streak of 1
        let habit = createHabit(
            frequency: .daily,
            completionDates: [date(daysFromToday: 0)]
        )

        XCTAssertEqual(habit.currentStreak, 1, "Completing today should create streak of 1")
    }

    func testDailyHabit_NotCompletedToday() {
        // Test that streak continues if not completed today yet
        let habit = createHabit(
            frequency: .daily,
            completionDates: [
                date(daysFromToday: -2),
                date(daysFromToday: -1)
            ]
        )

        XCTAssertEqual(habit.currentStreak, 2, "Streak should count yesterday even if today not completed yet")
    }

    // MARK: - Weekdays Habit Tests

    func testWeekdaysHabit_SimpleStreak() {
        // Find a recent Friday to build a weekday streak
        var testDate = date(daysFromToday: 0)
        while weekday(of: testDate) != 6 { // 6 = Friday
            testDate = calendar.date(byAdding: .day, value: -1, to: testDate)!
        }

        let habit = createHabit(
            frequency: .weekdays,
            completionDates: [
                calendar.date(byAdding: .day, value: -4, to: testDate)!, // Mon
                calendar.date(byAdding: .day, value: -3, to: testDate)!, // Tue
                calendar.date(byAdding: .day, value: -2, to: testDate)!, // Wed
                calendar.date(byAdding: .day, value: -1, to: testDate)!, // Thu
                testDate  // Fri
            ]
        )

        XCTAssertEqual(habit.currentStreak, 5, "Weekdays habit should have 5-day streak")
    }

    func testWeekdaysHabit_SkipsWeekend() {
        // Find a recent Wednesday to test weekend skipping
        var testDate = date(daysFromToday: 0)
        while weekday(of: testDate) != 4 { // 4 = Wednesday
            testDate = calendar.date(byAdding: .day, value: -1, to: testDate)!
        }

        // Complete all weekdays across two weeks (Mon-Fri last week, Mon-Fri this week)
        let habit = createHabit(
            frequency: .weekdays,
            completionDates: [
                calendar.date(byAdding: .day, value: -9, to: testDate)!,  // Mon (last week)
                calendar.date(byAdding: .day, value: -8, to: testDate)!,  // Tue (last week)
                calendar.date(byAdding: .day, value: -7, to: testDate)!,  // Wed (last week)
                calendar.date(byAdding: .day, value: -6, to: testDate)!,  // Thu (last week)
                calendar.date(byAdding: .day, value: -5, to: testDate)!,  // Fri (last week)
                // Sat, Sun skipped (weekend - not due)
                calendar.date(byAdding: .day, value: -2, to: testDate)!,  // Mon (this week)
                calendar.date(byAdding: .day, value: -1, to: testDate)!,  // Tue (this week)
                testDate,  // Wed (this week)
                calendar.date(byAdding: .day, value: 1, to: testDate)!,   // Thu (this week)
                calendar.date(byAdding: .day, value: 2, to: testDate)!    // Fri (this week)
            ]
        )

        XCTAssertEqual(habit.currentStreak, 10, "Weekdays habit should skip weekends and maintain streak across weeks")
    }

    func testWeekdaysHabit_BrokenByMissingWeekday() {
        // Find a recent Friday
        var testDate = date(daysFromToday: 0)
        while weekday(of: testDate) != 6 { // 6 = Friday
            testDate = calendar.date(byAdding: .day, value: -1, to: testDate)!
        }

        let habit = createHabit(
            frequency: .weekdays,
            completionDates: [
                calendar.date(byAdding: .day, value: -4, to: testDate)!, // Mon
                // Missing Tuesday
                calendar.date(byAdding: .day, value: -2, to: testDate)!, // Wed
                calendar.date(byAdding: .day, value: -1, to: testDate)!, // Thu
                testDate  // Fri
            ]
        )

        XCTAssertEqual(habit.currentStreak, 3, "Missing weekday should break streak")
    }

    func testWeekdaysHabit_OnWeekend() {
        // Find a recent Saturday
        var testDate = date(daysFromToday: 0)
        while weekday(of: testDate) != 7 { // 7 = Saturday
            testDate = calendar.date(byAdding: .day, value: -1, to: testDate)!
        }

        // Complete all of last week's weekdays
        let habit = createHabit(
            frequency: .weekdays,
            completionDates: [
                calendar.date(byAdding: .day, value: -5, to: testDate)!, // Mon
                calendar.date(byAdding: .day, value: -4, to: testDate)!, // Tue
                calendar.date(byAdding: .day, value: -3, to: testDate)!, // Wed
                calendar.date(byAdding: .day, value: -2, to: testDate)!, // Thu
                calendar.date(byAdding: .day, value: -1, to: testDate)!  // Fri
            ]
        )

        // On Saturday, the streak should still count Friday
        XCTAssertEqual(habit.currentStreak, 5, "On weekend, streak should count last Friday")
    }

    // MARK: - Custom Days Habit Tests

    func testCustomDaysHabit_MondayWednesdayFriday() {
        // Find a recent Friday
        var testDate = date(daysFromToday: 0)
        while weekday(of: testDate) != 6 { // 6 = Friday
            testDate = calendar.date(byAdding: .day, value: -1, to: testDate)!
        }

        // Custom days: Monday (2), Wednesday (4), Friday (6)
        let habit = createHabit(
            frequency: .custom,
            customDays: [2, 4, 6],
            completionDates: [
                calendar.date(byAdding: .day, value: -11, to: testDate)!, // Mon (last week)
                calendar.date(byAdding: .day, value: -9, to: testDate)!,  // Wed (last week)
                calendar.date(byAdding: .day, value: -7, to: testDate)!,  // Fri (last week)
                calendar.date(byAdding: .day, value: -4, to: testDate)!,  // Mon (this week)
                calendar.date(byAdding: .day, value: -2, to: testDate)!,  // Wed (this week)
                testDate   // Fri (this week)
            ]
        )

        XCTAssertEqual(habit.currentStreak, 6, "Custom days (Mon/Wed/Fri) should skip other days")
    }

    func testCustomDaysHabit_BrokenStreak() {
        // Find a recent Friday
        var testDate = date(daysFromToday: 0)
        while weekday(of: testDate) != 6 { // 6 = Friday
            testDate = calendar.date(byAdding: .day, value: -1, to: testDate)!
        }

        // Custom days: Monday (2), Wednesday (4), Friday (6)
        let habit = createHabit(
            frequency: .custom,
            customDays: [2, 4, 6],
            completionDates: [
                calendar.date(byAdding: .day, value: -11, to: testDate)!, // Mon (last week)
                // Missing Wed (last week)
                calendar.date(byAdding: .day, value: -7, to: testDate)!,  // Fri (last week)
                calendar.date(byAdding: .day, value: -4, to: testDate)!,  // Mon (this week)
                calendar.date(byAdding: .day, value: -2, to: testDate)!,  // Wed (this week)
                testDate   // Fri (this week)
            ]
        )

        XCTAssertEqual(habit.currentStreak, 4, "Streak counts back to first missing due date")
    }

    func testCustomDaysHabit_WeekendsOnly() {
        // Find a recent Sunday
        var testDate = date(daysFromToday: 0)
        while weekday(of: testDate) != 1 { // 1 = Sunday
            testDate = calendar.date(byAdding: .day, value: -1, to: testDate)!
        }

        // Custom days: Saturday (7), Sunday (1)
        let habit = createHabit(
            frequency: .custom,
            customDays: [1, 7],
            completionDates: [
                calendar.date(byAdding: .day, value: -8, to: testDate)!,  // Sat (last week)
                calendar.date(byAdding: .day, value: -7, to: testDate)!,  // Sun (last week)
                calendar.date(byAdding: .day, value: -1, to: testDate)!,  // Sat (this week)
                testDate   // Sun (this week)
            ]
        )

        XCTAssertEqual(habit.currentStreak, 4, "Custom weekend days should work correctly")
    }

    func testCustomDaysHabit_OnOffDay() {
        // Find a recent Wednesday (off day for Mon/Fri habit)
        var testDate = date(daysFromToday: 0)
        while weekday(of: testDate) != 4 { // 4 = Wednesday
            testDate = calendar.date(byAdding: .day, value: -1, to: testDate)!
        }

        // Custom days: Monday (2), Friday (6)
        let habit = createHabit(
            frequency: .custom,
            customDays: [2, 6],
            completionDates: [
                calendar.date(byAdding: .day, value: -9, to: testDate)!,  // Mon (last week)
                calendar.date(byAdding: .day, value: -5, to: testDate)!,  // Fri (last week)
                calendar.date(byAdding: .day, value: -2, to: testDate)!,  // Mon (this week)
                calendar.date(byAdding: .day, value: 2, to: testDate)!    // Fri (this week) - after testDate
            ]
        )

        // Streak counts all completed due dates going backwards
        XCTAssertEqual(habit.currentStreak, 4, "Streak counts backwards through all completed due dates")
    }

    // MARK: - Skip Dates Tests

    func testDailyHabit_SkippedDay() {
        // Explicitly skipped days should break the streak
        let habit = createHabit(
            frequency: .daily,
            completionDates: [
                date(daysFromToday: -4),
                date(daysFromToday: -3)
            ],
            skipDates: [
                date(daysFromToday: -2)  // Explicitly skipped
            ]
        )

        // Streak should be broken by the skip
        XCTAssertEqual(habit.currentStreak, 0, "Explicitly skipped day should break streak")
    }

    func testDailyHabit_SkippedButOlderStreak() {
        // Skipped today, but yesterday completed
        let habit = createHabit(
            frequency: .daily,
            completionDates: [
                date(daysFromToday: -2),
                date(daysFromToday: -1)
            ],
            skipDates: [
                date(daysFromToday: 0)  // Skipped today
            ]
        )

        // Streak should break at today's skip
        XCTAssertEqual(habit.currentStreak, 0, "Skipping today should break the streak")
    }

    func testWeekdaysHabit_SkippedWeekday() {
        // Find a recent Friday
        var testDate = date(daysFromToday: 0)
        while weekday(of: testDate) != 6 { // 6 = Friday
            testDate = calendar.date(byAdding: .day, value: -1, to: testDate)!
        }

        let habit = createHabit(
            frequency: .weekdays,
            completionDates: [
                calendar.date(byAdding: .day, value: -4, to: testDate)!, // Mon
                calendar.date(byAdding: .day, value: -3, to: testDate)!  // Tue
            ],
            skipDates: [
                calendar.date(byAdding: .day, value: -2, to: testDate)!  // Wed (skipped)
            ]
        )

        XCTAssertEqual(habit.currentStreak, 0, "Skipped weekday should break streak")
    }

    // MARK: - Edge Cases

    func testDailyHabit_CreatedToday() {
        // Habit created today and completed today
        let habit = createHabit(
            frequency: .daily,
            completionDates: [date(daysFromToday: 0)],
            createdDate: date(daysFromToday: 0)
        )

        XCTAssertEqual(habit.currentStreak, 1, "New habit completed today should have streak of 1")
    }

    func testDailyHabit_CreatedYesterday_NotCompletedYesterday() {
        // Habit created yesterday but not completed yesterday, completed today
        let habit = createHabit(
            frequency: .daily,
            completionDates: [date(daysFromToday: 0)],
            createdDate: date(daysFromToday: -1)
        )

        // This should break the streak because yesterday was missed
        XCTAssertEqual(habit.currentStreak, 1, "Missing yesterday should only count today")
    }

    func testDailyHabit_CreatedLongAgo_CompletedRecently() {
        // Old habit with recent activity
        let habit = createHabit(
            frequency: .daily,
            completionDates: [
                date(daysFromToday: -2),
                date(daysFromToday: -1),
                date(daysFromToday: 0)
            ],
            createdDate: date(daysFromToday: -365)
        )

        XCTAssertEqual(habit.currentStreak, 3, "Should count recent streak regardless of creation date")
    }

    func testWeekdaysHabit_CreatedOnWeekend() {
        // Find a recent Saturday
        var testDate = date(daysFromToday: 0)
        while weekday(of: testDate) != 7 { // 7 = Saturday
            testDate = calendar.date(byAdding: .day, value: -1, to: testDate)!
        }

        // Habit created on Saturday (not a due day)
        let habit = createHabit(
            frequency: .weekdays,
            completionDates: [
                calendar.date(byAdding: .day, value: 2, to: testDate)!  // Monday
            ],
            createdDate: testDate
        )

        XCTAssertEqual(habit.currentStreak, 1, "Habit created on non-due day should work correctly")
    }

    func testDailyHabit_UnorderedCompletionDates() {
        // Test that dates don't need to be in order
        let habit = createHabit(
            frequency: .daily,
            completionDates: [
                date(daysFromToday: 0),
                date(daysFromToday: -2),
                date(daysFromToday: -1),
                date(daysFromToday: -3)
            ]
        )

        XCTAssertEqual(habit.currentStreak, 4, "Should handle unordered completion dates")
    }

    func testDailyHabit_DuplicateCompletionDates() {
        // Test that duplicate dates are handled correctly
        let habit = createHabit(
            frequency: .daily,
            completionDates: [
                date(daysFromToday: 0),
                date(daysFromToday: 0),  // Duplicate
                date(daysFromToday: -1),
                date(daysFromToday: -1)  // Duplicate
            ]
        )

        XCTAssertEqual(habit.currentStreak, 2, "Should handle duplicate dates correctly")
    }

    // MARK: - Helper Methods Tests (isDueOn)

    func testIsDueOn_DailyHabit() {
        let habit = createHabit(frequency: .daily)

        XCTAssertTrue(habit.isDueOn(date: date(daysFromToday: 0)), "Daily habit should be due today")
        XCTAssertTrue(habit.isDueOn(date: date(daysFromToday: -1)), "Daily habit should be due yesterday")
        XCTAssertTrue(habit.isDueOn(date: date(daysFromToday: 1)), "Daily habit should be due tomorrow")
    }

    func testIsDueOn_WeekdaysHabit() {
        let habit = createHabit(frequency: .weekdays)

        // Find a Monday
        var monday = date(daysFromToday: 0)
        while weekday(of: monday) != 2 {
            monday = calendar.date(byAdding: .day, value: -1, to: monday)!
        }

        XCTAssertTrue(habit.isDueOn(date: monday), "Weekdays habit should be due on Monday")
        XCTAssertTrue(habit.isDueOn(date: calendar.date(byAdding: .day, value: 1, to: monday)!), "Should be due on Tuesday")
        XCTAssertTrue(habit.isDueOn(date: calendar.date(byAdding: .day, value: 4, to: monday)!), "Should be due on Friday")
        XCTAssertFalse(habit.isDueOn(date: calendar.date(byAdding: .day, value: 5, to: monday)!), "Should NOT be due on Saturday")
        XCTAssertFalse(habit.isDueOn(date: calendar.date(byAdding: .day, value: 6, to: monday)!), "Should NOT be due on Sunday")
    }

    func testIsDueOn_CustomDaysHabit() {
        // Monday (2), Wednesday (4), Friday (6)
        let habit = createHabit(
            frequency: .custom,
            customDays: [2, 4, 6]
        )

        // Find a Monday
        var monday = date(daysFromToday: 0)
        while weekday(of: monday) != 2 {
            monday = calendar.date(byAdding: .day, value: -1, to: monday)!
        }

        XCTAssertTrue(habit.isDueOn(date: monday), "Should be due on Monday")
        XCTAssertFalse(habit.isDueOn(date: calendar.date(byAdding: .day, value: 1, to: monday)!), "Should NOT be due on Tuesday")
        XCTAssertTrue(habit.isDueOn(date: calendar.date(byAdding: .day, value: 2, to: monday)!), "Should be due on Wednesday")
        XCTAssertFalse(habit.isDueOn(date: calendar.date(byAdding: .day, value: 3, to: monday)!), "Should NOT be due on Thursday")
        XCTAssertTrue(habit.isDueOn(date: calendar.date(byAdding: .day, value: 4, to: monday)!), "Should be due on Friday")
    }

    func testIsDueOn_BeforeCreationDate() {
        let creationDate = date(daysFromToday: -10)
        let habit = createHabit(
            frequency: .daily,
            createdDate: creationDate
        )

        XCTAssertFalse(habit.isDueOn(date: date(daysFromToday: -11)), "Should not be due before creation date")
        XCTAssertTrue(habit.isDueOn(date: creationDate), "Should be due on creation date")
        XCTAssertTrue(habit.isDueOn(date: date(daysFromToday: -9)), "Should be due after creation date")
    }

    // MARK: - Status Methods Tests

    func testMarkCompleted() {
        var habit = createHabit(frequency: .daily)
        let testDate = date(daysFromToday: 0)

        XCTAssertFalse(habit.isCompletedOn(date: testDate), "Should not be completed initially")

        habit.markCompleted(on: testDate)
        XCTAssertTrue(habit.isCompletedOn(date: testDate), "Should be completed after marking")
        XCTAssertEqual(habit.currentStreak, 1, "Should have streak of 1")
    }

    func testMarkSkipped() {
        var habit = createHabit(frequency: .daily)
        let testDate = date(daysFromToday: 0)

        XCTAssertFalse(habit.isSkippedOn(date: testDate), "Should not be skipped initially")

        habit.markSkipped(on: testDate)
        XCTAssertTrue(habit.isSkippedOn(date: testDate), "Should be skipped after marking")
    }

    func testMarkCompleted_RemovesSkip() {
        var habit = createHabit(
            frequency: .daily,
            skipDates: [date(daysFromToday: 0)]
        )
        let testDate = date(daysFromToday: 0)

        XCTAssertTrue(habit.isSkippedOn(date: testDate), "Should be skipped initially")

        habit.markCompleted(on: testDate)
        XCTAssertFalse(habit.isSkippedOn(date: testDate), "Skip should be removed")
        XCTAssertTrue(habit.isCompletedOn(date: testDate), "Should be completed")
    }

    func testMarkSkipped_RemovesCompletion() {
        var habit = createHabit(
            frequency: .daily,
            completionDates: [date(daysFromToday: 0)]
        )
        let testDate = date(daysFromToday: 0)

        XCTAssertTrue(habit.isCompletedOn(date: testDate), "Should be completed initially")

        habit.markSkipped(on: testDate)
        XCTAssertFalse(habit.isCompletedOn(date: testDate), "Completion should be removed")
        XCTAssertTrue(habit.isSkippedOn(date: testDate), "Should be skipped")
    }
}
