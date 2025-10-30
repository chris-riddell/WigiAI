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

}
