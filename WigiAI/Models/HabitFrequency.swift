//
//  HabitFrequency.swift
//  WigiAI
//
//  Habit frequency options
//

import Foundation

/// Defines how often a habit should be performed
///
/// Used in conjunction with the `Habit` model to determine which days
/// a habit is considered "due" for tracking purposes.
enum HabitFrequency: String, Codable, CaseIterable, Hashable {
    /// Habit should be performed every day
    case daily = "Daily"

    /// Habit should be performed Monday through Friday
    case weekdays = "Weekdays"

    /// Habit should be performed Saturday and Sunday
    case weekends = "Weekends"

    /// Habit should be performed on specific days (configured separately)
    case custom = "Custom Days"

    /// Human-readable description of the frequency
    var description: String {
        switch self {
        case .daily:
            return "Every day"
        case .weekdays:
            return "Monday through Friday"
        case .weekends:
            return "Saturday and Sunday"
        case .custom:
            return "Specific days of the week"
        }
    }

    /// Determines if the habit is active on a specific date
    /// - Parameter date: The date to check
    /// - Returns: `true` if the habit is scheduled for this date based on the frequency
    /// - Note: For `.custom` frequency, this always returns `true` and the actual check
    ///         is performed by the `Habit` model using its `customDays` property
    func isActiveOn(date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday

        switch self {
        case .daily:
            return true
        case .weekdays:
            return weekday >= 2 && weekday <= 6  // Monday-Friday
        case .weekends:
            return weekday == 1 || weekday == 7  // Saturday-Sunday
        case .custom:
            return true  // Custom days handled separately in Habit model
        }
    }
}
