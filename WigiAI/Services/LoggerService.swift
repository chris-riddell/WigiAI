//
//  LoggerService.swift
//  WigiAI
//
//  Centralized logging service using os.log framework
//

import Foundation
import OSLog

/// Centralized logging service with category-based loggers
final class LoggerService {

    // MARK: - Singleton

    static let shared = LoggerService()

    private init() {}

    // MARK: - Log Categories

    /// Logger for chat-related operations
    static let chat = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.wigiai", category: "chat")

    /// Logger for AI service operations (API calls, streaming, context)
    static let ai = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.wigiai", category: "ai")

    /// Logger for voice interaction (STT, TTS)
    static let voice = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.wigiai", category: "voice")

    /// Logger for storage operations (save, load, verify)
    static let storage = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.wigiai", category: "storage")

    /// Logger for habit tracking operations
    static let habits = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.wigiai", category: "habits")

    /// Logger for reminder and notification operations
    static let reminders = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.wigiai", category: "reminders")

    /// Logger for sound effects
    static let sound = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.wigiai", category: "sound")

    /// Logger for UI-related operations
    static let ui = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.wigiai", category: "ui")

    /// Logger for app lifecycle and general operations
    static let app = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.wigiai", category: "app")

    /// Logger for auto-update operations
    static let updates = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.wigiai", category: "updates")

    // MARK: - Convenience Methods (removed - use category loggers directly)
    // Example: LoggerService.chat.info("Message")
    //          LoggerService.ai.error("Error")

    // MARK: - Privacy-Aware Logging

    /// Log user content with privacy protection
    static func logUserContent(_ message: String, content: String, category: Logger) {
        // Only log first 50 chars of user content
        let preview = String(content.prefix(50))
        category.info("\(message, privacy: .public): '\(preview, privacy: .private)...'")
    }
}

// MARK: - Emoji Helpers

extension LoggerService {
    /// Common emoji prefixes for quick visual scanning in Console.app
    enum Emoji {
        static let chat = "💬"
        static let ai = "🤖"
        static let voice = "🎤"
        static let storage = "💾"
        static let habits = "🎯"
        static let reminders = "🔔"
        static let sound = "🔊"
        static let ui = "🎨"
        static let app = "📱"
        static let updates = "⬆️"
        static let success = "✅"
        static let error = "❌"
        static let warning = "⚠️"
        static let info = "ℹ️"
        static let debug = "🔍"
        static let network = "🌐"
        static let celebration = "🎉"
        static let fire = "🔥"
    }
}
