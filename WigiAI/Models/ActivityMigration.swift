//
//  ActivityMigration.swift
//  WigiAI
//
//  Migration utilities for converting legacy Reminder + Habit models to unified Activity model
//

import Foundation

extension Activity {
    /// Creates an Activity from a legacy Reminder (without tracking)
    /// - Parameter reminder: The legacy reminder to migrate
    /// - Returns: A new Activity instance representing the reminder
    static func fromReminder(_ reminder: Reminder) -> Activity {
        Activity(
            id: reminder.id,
            name: reminder.reminderText,  // Use reminder text as name
            description: "",
            scheduledTime: reminder.time,
            frequency: .daily,  // Legacy reminders were daily
            customDays: nil,
            isTrackingEnabled: false,  // Simple reminders don't track
            completionDates: [],
            skipDates: [],
            createdDate: Date(),  // No creation date in legacy model
            isEnabled: reminder.isEnabled,
            lastTriggered: reminder.lastTriggered,
            icon: nil,
            color: nil,
            category: "reminder"
        )
    }

    /// Creates an Activity from a legacy Habit (with tracking enabled)
    /// - Parameter habit: The legacy habit to migrate
    /// - Returns: A new Activity instance representing the habit
    static func fromHabit(_ habit: Habit) -> Activity {
        // Map HabitFrequency to ActivityFrequency
        let activityFrequency: ActivityFrequency
        switch habit.frequency {
        case .daily:
            activityFrequency = .daily
        case .weekdays:
            activityFrequency = .weekdays
        case .weekends:
            activityFrequency = .weekends
        case .custom:
            activityFrequency = .custom
        }

        return Activity(
            id: habit.id,
            name: habit.name,
            description: habit.targetDescription,
            scheduledTime: habit.reminderTime,  // May be nil
            frequency: activityFrequency,
            customDays: habit.customDays,
            isTrackingEnabled: true,  // Habits always track
            completionDates: habit.completionDates,
            skipDates: habit.skipDates,
            createdDate: habit.createdDate,
            isEnabled: habit.isEnabled,
            lastTriggered: nil,  // Habits didn't track this
            icon: nil,
            color: nil,
            category: "habit"
        )
    }

    /// Converts a Habit-linked Reminder to an Activity, merging with the associated Habit
    /// - Parameters:
    ///   - reminder: The reminder linked to a habit
    ///   - habit: The associated habit
    /// - Returns: A merged Activity instance
    static func fromLinkedReminderAndHabit(reminder: Reminder, habit: Habit) -> Activity {
        Activity(
            id: habit.id,  // Use habit ID as primary
            name: habit.name,
            description: habit.targetDescription,
            scheduledTime: reminder.time,  // Use reminder's time
            frequency: {
                switch habit.frequency {
                case .daily: return .daily
                case .weekdays: return .weekdays
                case .weekends: return .weekends
                case .custom: return .custom
                }
            }(),
            customDays: habit.customDays,
            isTrackingEnabled: true,
            completionDates: habit.completionDates,
            skipDates: habit.skipDates,
            createdDate: habit.createdDate,
            isEnabled: reminder.isEnabled && habit.isEnabled,  // Both must be enabled
            lastTriggered: reminder.lastTriggered,
            icon: nil,
            color: nil,
            category: "habit"
        )
    }
}

extension Character {
    /// Migrates legacy reminders and habits to the unified activities array
    ///
    /// **Migration Strategy:**
    /// 1. For each Habit: Create Activity with tracking enabled
    /// 2. For Reminders linked to Habits: Merge time/enabled status into Activity
    /// 3. For standalone Reminders: Create Activity without tracking
    ///
    /// **Data Safety:**
    /// - Preserves all completion dates and skip dates
    /// - Maintains streak calculations
    /// - Keeps notification schedules
    /// - Non-destructive: Returns new Character instance
    ///
    /// - Returns: Migrated Character with activities array populated
    func migrateToActivities() -> Character {
        var migratedCharacter = self

        // If already has activities, assume migration is done
        if !migratedCharacter.activities.isEmpty {
            return migratedCharacter
        }

        var newActivities: [Activity] = []
        var processedReminderIds = Set<UUID>()

        // Step 1: Migrate all habits to activities (with tracking enabled)
        for habit in habits {
            // Check if there's a linked reminder for this habit
            if let linkedReminder = reminders.first(where: { $0.linkedHabitId == habit.id }) {
                // Merge habit with its linked reminder
                let activity = Activity.fromLinkedReminderAndHabit(
                    reminder: linkedReminder,
                    habit: habit
                )
                newActivities.append(activity)
                processedReminderIds.insert(linkedReminder.id)
            } else {
                // Standalone habit (no reminder time)
                let activity = Activity.fromHabit(habit)
                newActivities.append(activity)
            }
        }

        // Step 2: Migrate standalone reminders (no habit link)
        for reminder in reminders {
            // Skip if already processed as habit-linked reminder
            if processedReminderIds.contains(reminder.id) {
                continue
            }

            // Skip if this was a habit-linked reminder (but habit not found)
            if reminder.linkedHabitId != nil {
                LoggerService.app.warning("⚠️ Found orphaned habit-linked reminder: \(reminder.id)")
                continue
            }

            // Convert to simple activity (no tracking)
            let activity = Activity.fromReminder(reminder)
            newActivities.append(activity)
        }

        migratedCharacter.activities = newActivities

        LoggerService.app.info("✅ Migrated character '\(name)': \(habits.count) habits + \(reminders.count) reminders → \(newActivities.count) activities")

        return migratedCharacter
    }
}
