//
//  ReminderService.swift
//  WigiAI
//
//  AI Companion Desktop Widget
//

import Foundation
import OSLog
import UserNotifications
import AppKit

/// Manages notification permissions and reminder scheduling for characters
///
/// Handles macOS notification permissions, schedules both general reminders and
/// habit-specific reminders, and manages the lifecycle of notifications.
///
/// **Key Features:**
/// - Automatic permission request and handling
/// - Daily recurring reminders for characters
/// - Habit-specific reminder scheduling
/// - Notification metadata for triggering character actions
class ReminderService: NSObject, ObservableObject {
    /// Shared singleton instance
    static let shared = ReminderService()

    /// Whether notification permissions have been granted
    @Published var notificationPermissionGranted = false

    /// Initializes the service and checks notification permissions
    private override init() {
        super.init()
        checkAndRequestPermission()
    }

    // MARK: - Check Authorization Status

    /// Checks notification authorization status and requests permission if needed
    /// - Returns: `true` if authorized (including provisional), `false` otherwise
    private func checkNotificationAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true

        case .notDetermined:
            // Request authorization
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    LoggerService.reminders.info("✅ Notification authorization granted")
                } else {
                    LoggerService.reminders.warning("⚠️ Notification authorization denied by user")
                }
                return granted
            } catch {
                LoggerService.reminders.warning("⚠️ Failed to request notification authorization: \(error.localizedDescription)")
                return false
            }

        case .denied:
            LoggerService.reminders.warning("⚠️ Notifications denied - user must enable in System Settings")
            return false

        case .ephemeral:
            LoggerService.reminders.debug("ℹ️ Using ephemeral notification authorization")
            return true

        @unknown default:
            LoggerService.reminders.warning("⚠️ Unknown authorization status")
            return false
        }
    }

    // MARK: - Check and Request Permission

    /// Checks current notification permission status and requests if needed
    ///
    /// Updates `notificationPermissionGranted` published property and shows
    /// alerts if permissions are denied.
    func checkAndRequestPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    LoggerService.reminders.info("✅ Notifications: Authorized")
                    self.notificationPermissionGranted = true
                    // Send a test notification to register the app with System Settings
                    self.sendRegistrationNotification()

                case .denied:
                    LoggerService.reminders.error("❌ Notifications: Denied - Please enable in System Settings → Notifications → WigiAI")
                    self.notificationPermissionGranted = false
                    self.showNotificationPermissionAlert()

                case .notDetermined:
                    print("⏳ Notifications: Requesting permission...")
                    self.requestNotificationPermission()

                case .ephemeral:
                    LoggerService.reminders.warning("⚠️ Notifications: Ephemeral (App Clips)")
                    self.notificationPermissionGranted = false

                @unknown default:
                    LoggerService.reminders.warning("⚠️ Notifications: Unknown status")
                    self.notificationPermissionGranted = false
                }
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if granted {
                    LoggerService.reminders.info("✅ Notification permission granted!")
                    self.notificationPermissionGranted = true
                    // Send a test notification to register the app with System Settings
                    self.sendRegistrationNotification()
                } else {
                    LoggerService.reminders.error("❌ Notification permission denied")
                    if let error = error {
                        print("   Error: \(error.localizedDescription)")
                    }
                    self.notificationPermissionGranted = false
                    self.showNotificationPermissionAlert()
                }
            }
        }
    }

    // MARK: - Registration Notification
    // Sends a test notification to register the app with macOS System Settings
    // This is necessary because macOS doesn't list the app in System Settings → Notifications
    // until it actually attempts to send a notification, not just request permission
    private func sendRegistrationNotification() {
        LoggerService.app.debug("📬 Sending registration notification to register app with System Settings...")

        let content = UNMutableNotificationContent()
        content.title = "WigiAI Ready!"
        content.body = "Your AI companions are ready to help you. Check the menubar to get started."
        content.sound = .default

        // Trigger immediately (after 1 second)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "wigiaiRegistrationNotification",
            content: content,
            trigger: trigger
        )

        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
                LoggerService.reminders.info("✅ Registration notification scheduled - app will now appear in System Settings")
            } catch {
                LoggerService.reminders.error("❌ Error sending registration notification: \(error)")
            }
        }
    }

    private func showNotificationPermissionAlert() {
        DispatchQueue.main.async { [weak self] in
            guard self != nil else { return }
            let alert = NSAlert()
            alert.messageText = "Notification Permission Required"
            alert.informativeText = "WigiAI needs notification permission to send you reminders from your characters.\n\nTo enable:\n1. Open System Settings\n2. Go to Notifications\n3. Find WigiAI and enable notifications"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open System Settings to Notifications
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    // MARK: - Schedule Reminders for Character

    /// Schedules all enabled reminders for a character
    /// - Parameter character: The character whose reminders should be scheduled
    /// - Note: Cancels existing reminders before scheduling new ones
    func scheduleReminders(for character: Character) {
        // Remove existing reminders for this character
        cancelReminders(for: character.id)

        // Schedule each enabled reminder asynchronously
        Task {
            for reminder in character.reminders where reminder.isEnabled {
                await scheduleReminder(reminder, for: character)
            }
        }
    }

    // MARK: - Schedule Single Reminder

    /// Schedules a single reminder for a character
    /// - Parameters:
    ///   - reminder: The reminder to schedule
    ///   - character: The character this reminder belongs to
    /// - Note: Includes character and reminder IDs in notification metadata
    private func scheduleReminder(_ reminder: Reminder, for character: Character) async {
        // Check authorization first
        let authorized = await checkNotificationAuthorization()
        guard authorized else {
            LoggerService.reminders.warning("⚠️ Cannot schedule reminder - no notification authorization")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = character.name
        content.body = reminder.reminderText
        content.sound = .default

        // Add character ID to userInfo for triggering badge
        content.userInfo = [
            "characterId": character.id.uuidString,
            "reminderId": reminder.id.uuidString
        ]

        // Create date components from reminder time
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: reminder.time)

        // Create trigger that repeats daily at specified time
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        // Create request
        let request = UNNotificationRequest(
            identifier: "\(character.id.uuidString)-\(reminder.id.uuidString)",
            content: content,
            trigger: trigger
        )

        // Schedule notification
        do {
            try await UNUserNotificationCenter.current().add(request)
            LoggerService.app.debug("Scheduled reminder for \(character.name) at \(reminder.time)")
        } catch {
            LoggerService.app.debug("Error scheduling reminder: \(error)")
        }
    }

    // MARK: - Cancel Reminders

    /// Cancels all reminders for a specific character
    /// - Parameter characterId: UUID of the character
    func cancelReminders(for characterId: UUID) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToRemove = requests
                .filter { $0.identifier.starts(with: characterId.uuidString) }
                .map { $0.identifier }

            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
            LoggerService.app.debug("Cancelled \(identifiersToRemove.count) reminders for character \(characterId)")
        }
    }

    // MARK: - Cancel All Reminders

    /// Cancels all pending reminders for all characters
    func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        LoggerService.app.debug("Cancelled all reminders")
    }

    // MARK: - Get Pending Reminders

    /// Retrieves all currently scheduled notification requests
    /// - Parameter completion: Callback with array of pending notifications
    func getPendingReminders(completion: @escaping ([UNNotificationRequest]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            completion(requests)
        }
    }

    // MARK: - Habit Reminder Management

    /// Schedules reminders for all habits that have reminder times configured
    /// - Parameter character: The character whose habit reminders should be scheduled
    /// - Note: Only schedules reminders for enabled habits with non-nil `reminderTime`
    func scheduleHabitReminders(for character: Character) {
        // Cancel existing habit reminders for this character
        cancelHabitReminders(for: character.id)

        // Schedule each enabled habit that has a reminder time asynchronously
        Task {
            for habit in character.habits where habit.isEnabled && habit.reminderTime != nil {
                await scheduleHabitReminder(habit, for: character)
            }
        }
    }

    /// Schedules a notification for a single habit
    /// - Parameters:
    ///   - habit: The habit to schedule a reminder for
    ///   - character: The character this habit belongs to
    /// - Note: Requires a linked reminder in character.reminders for proper notification handling
    private func scheduleHabitReminder(_ habit: Habit, for character: Character) async {
        // Check authorization first
        let authorized = await checkNotificationAuthorization()
        guard authorized else {
            LoggerService.reminders.warning("⚠️ Cannot schedule habit reminder - no notification authorization")
            return
        }
        guard let reminderTime = habit.reminderTime else { return }

        // Find the corresponding reminder in character.reminders
        guard let linkedReminder = character.reminders.first(where: { $0.linkedHabitId == habit.id }) else {
            LoggerService.reminders.warning("⚠️ No linked reminder found for habit '\(habit.name)' - skipping notification schedule")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "\(character.name) - \(habit.name)"
        content.body = "Time to check in! \(habit.targetDescription)"
        content.sound = .default

        // Add metadata for habit tracking (include reminderId for notification handling)
        content.userInfo = [
            "characterId": character.id.uuidString,
            "reminderId": linkedReminder.id.uuidString,  // Use linked reminder ID
            "habitId": habit.id.uuidString,
            "isHabitReminder": true
        ]

        // Create date components from reminder time
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: reminderTime)

        // Create trigger based on habit frequency
        let trigger: UNNotificationTrigger

        if habit.frequency == .daily {
            // Daily reminder - simple case
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        } else {
            // For other frequencies, we'd need to check each day
            // For now, we'll use daily trigger and check in the app
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }

        // Create request with habit-specific identifier
        let request = UNNotificationRequest(
            identifier: "habit-\(character.id.uuidString)-\(habit.id.uuidString)",
            content: content,
            trigger: trigger
        )

        // Schedule notification
        do {
            try await UNUserNotificationCenter.current().add(request)
            LoggerService.reminders.info("✅ Scheduled habit reminder for '\(habit.name)' at \(reminderTime)")
        } catch {
            LoggerService.reminders.error("❌ Error scheduling habit reminder: \(error)")
        }
    }

    /// Cancels all habit reminders for a specific character
    /// - Parameter characterId: UUID of the character
    func cancelHabitReminders(for characterId: UUID) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToRemove = requests
                .filter { $0.identifier.starts(with: "habit-\(characterId.uuidString)") }
                .map { $0.identifier }

            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
            LoggerService.app.debug("🗑️ Cancelled \(identifiersToRemove.count) habit reminders for character \(characterId)")
        }
    }

    /// Cancels a reminder for a specific habit
    /// - Parameters:
    ///   - habitId: UUID of the habit
    ///   - characterId: UUID of the character who owns the habit
    func cancelHabitReminder(habitId: UUID, characterId: UUID) {
        let identifier = "habit-\(characterId.uuidString)-\(habitId.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        LoggerService.app.debug("🗑️ Cancelled habit reminder: \(identifier)")
    }
}

