//
//  Habit.swift
//  WigiAI
//
//  Habit tracking model for AI companions
//

import Foundation

/// Represents a trackable habit for a character
///
/// Habits include flexible scheduling, completion tracking, streak calculation,
/// and optional reminder integration. The AI can track habit completion through
/// natural conversation using special markers in messages.
struct Habit: Codable, Identifiable, Hashable {
    /// Unique identifier for the habit
    let id: UUID

    /// Display name of the habit (e.g., "Exercise", "Read")
    var name: String

    /// Specific target or goal description (e.g., "30 minutes of cardio", "Read 20 pages")
    var targetDescription: String

    /// How often the habit should be performed
    var frequency: HabitFrequency

    /// Custom days when habit is active (for `.custom` frequency)
    ///
    /// Values: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
    /// Only used when `frequency` is `.custom`
    var customDays: Set<Int>?

    /// Whether the habit is currently active
    var isEnabled: Bool

    /// Optional time for daily reminder notifications
    ///
    /// When set, a linked reminder is automatically created in the character's reminder list
    var reminderTime: Date?

    /// Dates when the habit was successfully completed (stored as start of day)
    var completionDates: [Date]

    /// Dates when the habit was explicitly skipped (stored as start of day)
    var skipDates: [Date]

    /// When the habit was created (used to determine valid tracking dates)
    var createdDate: Date

    init(
        id: UUID = UUID(),
        name: String,
        targetDescription: String,
        frequency: HabitFrequency = .daily,
        customDays: Set<Int>? = nil,
        isEnabled: Bool = true,
        reminderTime: Date? = nil,
        completionDates: [Date] = [],
        skipDates: [Date] = [],
        createdDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.targetDescription = targetDescription
        self.frequency = frequency
        self.customDays = customDays
        self.isEnabled = isEnabled
        self.reminderTime = reminderTime
        self.completionDates = completionDates
        self.skipDates = skipDates
        self.createdDate = createdDate
    }

    // MARK: - Computed Properties

    /// Current streak of consecutive completions on scheduled days
    ///
    /// Calculates the number of consecutive scheduled days the habit has been completed,
    /// starting from today (or yesterday if the habit isn't due today) and counting backwards.
    /// Only counts days when the habit was actually scheduled based on its frequency.
    var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Deduplicate dates
        let uniqueCompletions = Set(completionDates.map { calendar.startOfDay(for: $0) })
        let uniqueSkips = Set(skipDates.map { calendar.startOfDay(for: $0) })

        // If today is due and skipped, streak is 0
        if isDueOn(date: today) && uniqueSkips.contains(today) {
            return 0
        }

        var checkDate = today
        var streak = 0

        // If habit is due today
        if isDueOn(date: today) {
            if uniqueCompletions.contains(today) {
                // Today completed, start counting from today
                streak = 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: today)!
            } else {
                // Today not completed yet (grace period), start from yesterday
                checkDate = calendar.date(byAdding: .day, value: -1, to: today)!
            }
        } else {
            // Habit not due today, start from yesterday
            checkDate = calendar.date(byAdding: .day, value: -1, to: today)!
        }

        // Count backwards through ALL days, checking only due dates
        // This ensures we don't skip over any due dates
        while checkDate >= createdDate {
            if isDueOn(date: checkDate) {
                // This is a due date - check if it was skipped or completed
                if uniqueSkips.contains(checkDate) {
                    break // Skipped due date breaks the streak
                }

                if uniqueCompletions.contains(checkDate) {
                    streak += 1
                } else {
                    // Due date not completed, streak ends
                    break
                }
            }
            // Move to previous day (checking every day ensures we don't skip due dates)
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }

        return streak
    }

    /// Total number of completions all-time
    var totalCompletions: Int {
        completionDates.count
    }

    /// Completion rate over the last 30 days
    ///
    /// Calculates the percentage of scheduled days the habit was completed
    /// - Returns: Value between 0.0 and 1.0 representing the completion rate
    var completionRate: Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today)!

        let activeDays = (0..<30).compactMap { offset -> Date? in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            return isDueOn(date: date) ? date : nil
        }

        guard !activeDays.isEmpty else { return 0.0 }

        let completedInPeriod = completionDates.filter { date in
            let dayStart = calendar.startOfDay(for: date)
            return dayStart >= thirtyDaysAgo && dayStart <= today
        }.count

        return Double(completedInPeriod) / Double(activeDays.count)
    }

    // MARK: - Helper Methods

    /// Determines if the habit is scheduled to be performed on a given date
    /// - Parameter date: The date to check
    /// - Returns: `true` if the habit should be tracked on this date
    /// - Note: Returns `false` for dates before the habit was created
    func isDueOn(date: Date) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        // Check if created after this date
        if dayStart < calendar.startOfDay(for: createdDate) {
            return false
        }

        switch frequency {
        case .daily:
            return true
        case .weekdays, .weekends:
            return frequency.isActiveOn(date: date)
        case .custom:
            guard let customDays = customDays, !customDays.isEmpty else {
                return false
            }
            let weekday = calendar.component(.weekday, from: date)
            return customDays.contains(weekday)
        }
    }

    /// Checks if the habit was marked as completed on a given date
    /// - Parameter date: The date to check
    /// - Returns: `true` if the habit was completed on this date
    func isCompletedOn(date: Date) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        return completionDates.contains { calendar.isDate($0, inSameDayAs: dayStart) }
    }

    /// Checks if the habit was marked as skipped on a given date
    /// - Parameter date: The date to check
    /// - Returns: `true` if the habit was skipped on this date
    func isSkippedOn(date: Date) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        return skipDates.contains { calendar.isDate($0, inSameDayAs: dayStart) }
    }

    /// Checks if the habit is pending for today (due but not completed or skipped)
    ///
    /// Used to determine if the habit needs attention in the UI or notifications
    var isPendingToday: Bool {
        let today = Date()
        return isDueOn(date: today) && !isCompletedOn(date: today) && !isSkippedOn(date: today)
    }

    // MARK: - Mutation Methods

    /// Marks the habit as completed for a given date
    /// - Parameter date: The date to mark as completed (defaults to today)
    /// - Note: Automatically removes any skip status for the same date
    mutating func markCompleted(on date: Date = Date()) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        // Remove from skip dates if present
        skipDates.removeAll { calendar.isDate($0, inSameDayAs: dayStart) }

        // Add to completion dates if not already present
        if !isCompletedOn(date: date) {
            completionDates.append(dayStart)
        }
    }

    /// Marks the habit as skipped for a given date
    /// - Parameter date: The date to mark as skipped (defaults to today)
    /// - Note: Automatically removes any completion status for the same date
    mutating func markSkipped(on date: Date = Date()) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        // Remove from completion dates if present
        completionDates.removeAll { calendar.isDate($0, inSameDayAs: dayStart) }

        // Add to skip dates if not already present
        if !isSkippedOn(date: date) {
            skipDates.append(dayStart)
        }
    }

    /// Clears any completion or skip status for a given date
    /// - Parameter date: The date to clear (defaults to today)
    /// - Note: Resets the date to "pending" state
    mutating func clearStatus(on date: Date = Date()) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        completionDates.removeAll { calendar.isDate($0, inSameDayAs: dayStart) }
        skipDates.removeAll { calendar.isDate($0, inSameDayAs: dayStart) }
    }

    /// Gets the status of the habit for a given date
    /// - Parameter date: The date to check
    /// - Returns: `true` if completed, `false` if skipped, `nil` if pending
    func statusOn(date: Date) -> Bool? {
        if isCompletedOn(date: date) {
            return true
        } else if isSkippedOn(date: date) {
            return false
        } else {
            return nil
        }
    }
}
