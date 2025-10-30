//
//  Activity.swift
//  WigiAI
//
//  Unified model combining reminders and habit tracking
//

import Foundation

/// Unified model for scheduled reminders and habit tracking
///
/// Activities can be simple one-time reminders, recurring notifications, or full habit trackers
/// with completion history and streak calculation. The same model serves both use cases,
/// making the app more flexible and intuitive.
///
/// **Examples:**
/// - Simple reminder: "Call dentist at 2pm" (no tracking)
/// - Recurring reminder: "Team standup daily at 9am" (no tracking)
/// - Habit: "Exercise daily at 7am" (with tracking, streaks, analytics)
struct Activity: Codable, Identifiable, Hashable {
    /// Unique identifier for the activity
    let id: UUID

    /// Display name (e.g., "Morning Exercise", "Call Mom", "Team Meeting")
    var name: String

    /// Detailed description or target (e.g., "30 mins cardio", "Discuss project updates")
    var description: String

    // MARK: - Scheduling

    /// Optional scheduled time for notifications
    ///
    /// If `nil`, this is a manual-only activity (no notifications)
    var scheduledTime: Date?

    /// How often this activity occurs
    var frequency: ActivityFrequency

    /// Custom days when activity is active (for `.custom` frequency)
    ///
    /// Values: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
    /// Only used when `frequency` is `.custom`
    var customDays: Set<Int>?

    // MARK: - Tracking

    /// Whether to track completion history (converts simple reminder → habit)
    ///
    /// When `true`, enables completion tracking, streaks, and analytics UI
    var isTrackingEnabled: Bool

    /// Dates when the activity was successfully completed (stored as start of day)
    var completionDates: [Date]

    /// Dates when the activity was explicitly skipped (stored as start of day)
    var skipDates: [Date]

    /// When the activity was created (used to determine valid tracking dates)
    var createdDate: Date

    // MARK: - Metadata

    /// Whether the activity is currently active
    var isEnabled: Bool

    /// Timestamp of the last time this reminder was triggered
    var lastTriggered: Date?

    /// Optional icon identifier for UI customization (future)
    var icon: String?

    /// Optional color identifier for UI customization (future)
    var color: String?

    /// Category/tag for organization (e.g., "health", "work", "social")
    var category: String

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        scheduledTime: Date? = nil,
        frequency: ActivityFrequency = .daily,
        customDays: Set<Int>? = nil,
        isTrackingEnabled: Bool = false,
        completionDates: [Date] = [],
        skipDates: [Date] = [],
        createdDate: Date = Date(),
        isEnabled: Bool = true,
        lastTriggered: Date? = nil,
        icon: String? = nil,
        color: String? = nil,
        category: String = "general"
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.scheduledTime = scheduledTime
        self.frequency = frequency
        self.customDays = customDays
        self.isTrackingEnabled = isTrackingEnabled
        self.completionDates = completionDates
        self.skipDates = skipDates
        self.createdDate = createdDate
        self.isEnabled = isEnabled
        self.lastTriggered = lastTriggered
        self.icon = icon
        self.color = color
        self.category = category
    }

    // MARK: - Computed Properties

    /// Current streak of consecutive completions on scheduled days (only if tracking enabled)
    ///
    /// Calculates the number of consecutive scheduled days the activity has been completed,
    /// starting from today (or yesterday if not due today) and counting backwards.
    var currentStreak: Int {
        guard isTrackingEnabled else { return 0 }

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

        // If activity is due today
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
            // Activity not due today, start from yesterday
            checkDate = calendar.date(byAdding: .day, value: -1, to: today)!
        }

        // Count backwards through ALL days, checking only due dates
        while checkDate >= createdDate {
            if isDueOn(date: checkDate) {
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
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }

        return streak
    }

    /// Total number of completions all-time (only if tracking enabled)
    var totalCompletions: Int {
        guard isTrackingEnabled else { return 0 }
        return completionDates.count
    }

    /// Completion rate over the last 30 days (only if tracking enabled)
    ///
    /// Calculates the percentage of scheduled days the activity was completed
    /// - Returns: Value between 0.0 and 1.0 representing the completion rate
    var completionRate: Double {
        guard isTrackingEnabled else { return 0.0 }

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

    /// Determines if the activity is scheduled to occur on a given date
    /// - Parameter date: The date to check
    /// - Returns: `true` if the activity should occur on this date
    /// - Note: Returns `false` for dates before the activity was created
    func isDueOn(date: Date) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        // Check if created after this date
        if dayStart < calendar.startOfDay(for: createdDate) {
            return false
        }

        return frequency.isActiveOn(date: date, customDays: customDays)
    }

    /// Checks if the activity was marked as completed on a given date
    /// - Parameter date: The date to check
    /// - Returns: `true` if the activity was completed on this date
    func isCompletedOn(date: Date) -> Bool {
        guard isTrackingEnabled else { return false }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        return completionDates.contains { calendar.isDate($0, inSameDayAs: dayStart) }
    }

    /// Checks if the activity was marked as skipped on a given date
    /// - Parameter date: The date to check
    /// - Returns: `true` if the activity was skipped on this date
    func isSkippedOn(date: Date) -> Bool {
        guard isTrackingEnabled else { return false }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        return skipDates.contains { calendar.isDate($0, inSameDayAs: dayStart) }
    }

    /// Checks if the activity is pending for today (due but not completed or skipped)
    var isPendingToday: Bool {
        guard isTrackingEnabled else { return false }
        let today = Date()
        return isDueOn(date: today) && !isCompletedOn(date: today) && !isSkippedOn(date: today)
    }

    // MARK: - Mutation Methods

    /// Marks the activity as completed for a given date
    /// - Parameter date: The date to mark as completed (defaults to today)
    /// - Note: Automatically removes any skip status for the same date
    mutating func markCompleted(on date: Date = Date()) {
        guard isTrackingEnabled else { return }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        // Remove from skip dates if present
        skipDates.removeAll { calendar.isDate($0, inSameDayAs: dayStart) }

        // Add to completion dates if not already present
        if !isCompletedOn(date: date) {
            completionDates.append(dayStart)
        }
    }

    /// Marks the activity as skipped for a given date
    /// - Parameter date: The date to mark as skipped (defaults to today)
    /// - Note: Automatically removes any completion status for the same date
    mutating func markSkipped(on date: Date = Date()) {
        guard isTrackingEnabled else { return }

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
        guard isTrackingEnabled else { return }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        completionDates.removeAll { calendar.isDate($0, inSameDayAs: dayStart) }
        skipDates.removeAll { calendar.isDate($0, inSameDayAs: dayStart) }
    }

    /// Gets the status of the activity for a given date
    /// - Parameter date: The date to check
    /// - Returns: `true` if completed, `false` if skipped, `nil` if pending
    func statusOn(date: Date) -> Bool? {
        guard isTrackingEnabled else { return nil }

        if isCompletedOn(date: date) {
            return true
        } else if isSkippedOn(date: date) {
            return false
        } else {
            return nil
        }
    }
}

// MARK: - Activity Frequency

/// Defines how often an activity occurs
enum ActivityFrequency: String, Codable, CaseIterable {
    case daily = "daily"
    case weekdays = "weekdays"
    case weekends = "weekends"
    case custom = "custom"
    case oneTime = "oneTime"  // For single reminders

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .weekends: return "Weekends"
        case .custom: return "Custom"
        case .oneTime: return "One Time"
        }
    }

    /// Checks if the frequency is active on a given date
    /// - Parameters:
    ///   - date: The date to check
    ///   - customDays: Custom days (required if frequency is .custom)
    /// - Returns: `true` if active on this date
    func isActiveOn(date: Date, customDays: Set<Int>? = nil) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)

        switch self {
        case .daily:
            return true
        case .weekdays:
            return weekday >= 2 && weekday <= 6  // Mon-Fri
        case .weekends:
            return weekday == 1 || weekday == 7  // Sun, Sat
        case .custom:
            guard let customDays = customDays, !customDays.isEmpty else {
                return false
            }
            return customDays.contains(weekday)
        case .oneTime:
            return false  // One-time activities don't recur
        }
    }
}
