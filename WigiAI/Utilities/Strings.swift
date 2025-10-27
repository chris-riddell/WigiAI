//
//  Strings.swift
//  WigiAI
//
//  Centralized strings for localization
//

import Foundation

enum Strings {
    // MARK: - Chat Window

    enum Chat {
        static let clearHistoryTitle = "Clear Conversation History"
        static let clearHistoryMessage = "This will delete all chat messages. The character's personality and current context will be preserved."
        static let clearButton = "Clear"
        static let cancelButton = "Cancel"
        static let startConversation = "Start a conversation"
        static let thinkingIndicator = "Thinking..."
        static let sendButton = "Send"
        static let settingsTooltip = "Character Settings"
        static let habitsTooltip = "Habit Progress"
        static let clearHistoryTooltip = "Clear History"
        static let closeTooltip = "Close Chat"
        static let ttsTooltip = "Toggle Text-to-Speech"
    }

    // MARK: - Voice

    enum Voice {
        static let permissionTitle = "Voice Permissions Required"
        static let permissionMessage = "WigiAI needs microphone and speech recognition permissions to use voice features. Please grant access in System Settings → Privacy & Security."
        static let openSettingsButton = "Open System Settings"
        static let pushToTalkTooltip = "Hold to speak"
        static let voiceInputPlaceholder = "Listening..."
    }

    // MARK: - Habits

    enum Habits {
        static let progressTitle = "Habit Progress"
        static let doneButton = "Done"
        static let skipButton = "Skip"
        static let completedToday = "Completed today"
        static let skippedToday = "Skipped today"
        static let pendingToday = "Pending"
        static let notDueToday = "Not due today"
        static let streakLabel = "day streak"
        static let daysLabel = "days"
        static let celebrationTitle = "Great job!"
        static let celebrationStreakMessage = "day streak!"
    }

    // MARK: - Settings

    enum Settings {
        static let windowTitle = "Settings"
        static let generalTab = "General"
        static let charactersTab = "Characters"
        static let apiTab = "API Settings"
        static let voiceTab = "Voice"

        // General
        static let launchAtLogin = "Launch at login"
        static let autoUpdateEnabled = "Check for updates automatically"
        static let messageHistoryCount = "Message history count"
        static let currentVersion = "Current version"

        // API
        static let apiURL = "API URL"
        static let apiKey = "API Key"
        static let model = "Model"
        static let temperature = "Temperature"
        static let useStreaming = "Use streaming"
        static let testConnection = "Test Connection"
        static let connectionSuccess = "Connection successful!"
        static let connectionFailed = "Connection failed"

        // Voice
        static let voiceEnabled = "Enable voice features"
        static let sttEnabled = "Speech-to-text (push-to-talk)"
        static let ttsEnabled = "Text-to-speech (AI responses)"
        static let autoSubmit = "Auto-submit after voice input"
        static let selectVoice = "Select voice"
        static let speechRate = "Speech rate"
        static let testVoice = "Test Voice"

        // Characters
        static let characterName = "Character name"
        static let masterPrompt = "Master prompt"
        static let customModel = "Custom model (optional)"
        static let customVoice = "Custom voice (optional)"
        static let customSpeechRate = "Custom speech rate"
        static let addCharacter = "Add Character"
        static let deleteCharacter = "Delete Character"
        static let duplicateCharacter = "Duplicate Character"
        static let exportCharacter = "Export Character"
        static let importCharacter = "Import Character"
    }

    // MARK: - Character Library

    enum CharacterLibrary {
        static let windowTitle = "Character Library"
        static let browseTitle = "Browse Templates"
        static let searchPlaceholder = "Search characters..."
        static let categoryAll = "All"
        static let categoryProductivity = "Productivity"
        static let categoryHealth = "Health"
        static let categoryLearning = "Learning"
        static let categoryFinance = "Finance"
        static let categoryLifestyle = "Lifestyle"
        static let categoryCreative = "Creative"
        static let addButton = "Add Character"
        static let habitsLabel = "habits"
        static let remindersLabel = "reminders"
    }

    // MARK: - Onboarding

    enum Onboarding {
        static let welcomeTitle = "Welcome to WigiAI"
        static let welcomeSubtitle = "Your AI companion desktop widget"
        static let step1Title = "Configure API"
        static let step1Description = "Connect to OpenAI or compatible API"
        static let step2Title = "Create Character"
        static let step2Description = "Design your AI companion's personality"
        static let step3Title = "Start Chatting"
        static let step3Description = "Your character is ready to help"
        static let nextButton = "Next"
        static let backButton = "Back"
        static let finishButton = "Get Started"
        static let skipButton = "Skip"
    }

    // MARK: - Errors

    enum Errors {
        static let saveFailed = "Failed to save"
        static let loadFailed = "Failed to load"
        static let networkError = "Network error occurred"
        static let invalidInput = "Invalid input"
        static let characterNotFound = "Character not found"
        static let permissionDenied = "Permission denied"
    }

    // MARK: - Common

    enum Common {
        static let ok = "OK"
        static let cancel = "Cancel"
        static let save = "Save"
        static let delete = "Delete"
        static let edit = "Edit"
        static let close = "Close"
        static let settings = "Settings"
        static let quit = "Quit"
        static let about = "About"
        static let help = "Help"
        static let yes = "Yes"
        static let no = "No"
    }

    // MARK: - Reminders

    enum Reminders {
        static let addReminder = "Add Reminder"
        static let editReminder = "Edit Reminder"
        static let deleteReminder = "Delete Reminder"
        static let reminderTime = "Time"
        static let reminderText = "Message"
        static let linkedHabit = "Linked to habit"
        static let enableReminder = "Enabled"
    }
}
