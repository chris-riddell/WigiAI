//
//  ActivityService.swift
//  WigiAI
//
//  Unified notification service for activities (replaces ReminderService)
//

import Foundation
import OSLog
import UserNotifications
import AppKit

/// Manages notification permissions and activity scheduling for characters
///
/// Handles macOS notification permissions and schedules notifications for activities
/// (both simple reminders and habit trackers).
///
/// **Key Features:**
/// - Automatic permission request and handling
/// - Unified scheduling for all activity types
/// - Notification metadata for triggering character actions
class ActivityService: NSObject, ObservableObject {
    /// Shared singleton instance
    static let shared = ActivityService()

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

    /// Sends a test notification to register the app with macOS System Settings
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

    // MARK: - Schedule Activities for Character

    /// Schedules all enabled activities for a character
    /// - Parameter character: The character whose activities should be scheduled
    /// - Note: Cancels existing activities before scheduling new ones
    func scheduleActivities(for character: Character) {
        // Remove existing activities for this character
        cancelActivities(for: character.id)

        // Schedule each enabled activity that has a scheduled time
        Task {
            for activity in character.activities where activity.isEnabled && activity.scheduledTime != nil {
                await scheduleActivity(activity, for: character)
            }
        }
    }

    // MARK: - Schedule Single Activity

    /// Schedules a single activity for a character
    /// - Parameters:
    ///   - activity: The activity to schedule
    ///   - character: The character this activity belongs to
    /// - Note: Includes character and activity IDs in notification metadata
    private func scheduleActivity(_ activity: Activity, for character: Character) async {
        // Check authorization first
        let authorized = await checkNotificationAuthorization()
        guard authorized else {
            LoggerService.reminders.warning("⚠️ Cannot schedule activity - no notification authorization")
            return
        }

        guard let scheduledTime = activity.scheduledTime else {
            return  // No schedule, nothing to do
        }

        let content = UNMutableNotificationContent()
        content.title = "\(character.name)\(activity.isTrackingEnabled ? " - \(activity.name)" : "")"
        content.body = activity.isTrackingEnabled && !activity.description.isEmpty
            ? activity.description
            : activity.name
        content.sound = .default

        // Add metadata for character and activity
        content.userInfo = [
            "characterId": character.id.uuidString,
            "activityId": activity.id.uuidString,
            "isTracked": activity.isTrackingEnabled
        ]

        // Create date components from scheduled time
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: scheduledTime)

        // Create trigger based on frequency
        let trigger: UNNotificationTrigger

        switch activity.frequency {
        case .oneTime:
            // One-time notification at specific date/time
            let fullComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: scheduledTime)
            trigger = UNCalendarNotificationTrigger(dateMatching: fullComponents, repeats: false)

        case .daily, .weekdays, .weekends, .custom:
            // Recurring notification at specific time
            // Note: For weekdays/weekends/custom, we schedule daily and check in-app
            // A better implementation would schedule separate notifications per day
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }

        // Create request
        let request = UNNotificationRequest(
            identifier: "\(character.id.uuidString)-\(activity.id.uuidString)",
            content: content,
            trigger: trigger
        )

        // Schedule notification
        do {
            try await UNUserNotificationCenter.current().add(request)
            let timeStr = DateFormatter.localizedString(from: scheduledTime, dateStyle: .none, timeStyle: .short)
            LoggerService.app.debug("✅ Scheduled activity '\(activity.name)' for \(character.name) at \(timeStr)")
        } catch {
            LoggerService.app.debug("❌ Error scheduling activity: \(error)")
        }
    }

    // MARK: - Cancel Activities

    /// Cancels all activities for a specific character
    /// - Parameter characterId: UUID of the character
    func cancelActivities(for characterId: UUID) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToRemove = requests
                .filter { $0.identifier.starts(with: characterId.uuidString) }
                .map { $0.identifier }

            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
            LoggerService.app.debug("🗑️ Cancelled \(identifiersToRemove.count) activities for character \(characterId)")
        }
    }

    /// Cancels a specific activity
    /// - Parameters:
    ///   - activityId: UUID of the activity
    ///   - characterId: UUID of the character who owns the activity
    func cancelActivity(activityId: UUID, characterId: UUID) {
        let identifier = "\(characterId.uuidString)-\(activityId.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        LoggerService.app.debug("🗑️ Cancelled activity: \(identifier)")
    }

    // MARK: - Cancel All

    /// Cancels all pending activities for all characters
    func cancelAllActivities() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        LoggerService.app.debug("🗑️ Cancelled all activities")
    }

    // MARK: - Get Pending

    /// Retrieves all currently scheduled notification requests
    /// - Parameter completion: Callback with array of pending notifications
    func getPendingActivities(completion: @escaping ([UNNotificationRequest]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            completion(requests)
        }
    }
}

