//
//  ChatViewModel.swift
//  WigiAI
//
//  Chat window view model - business logic and state management
//

import SwiftUI
import Speech
import OSLog

@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Constants

    private static let scrollDelay: TimeInterval = 0.3  // Delay before triggering scroll to bottom
    private static let thinkingDelay: TimeInterval = 0.5  // Delay before showing streaming response
    private static let widgetRecreationDelay: UInt64 = 100_000_000  // 0.1 seconds in nanoseconds
    private static let voiceAutoSubmitDelay: TimeInterval = 0.3  // Delay before auto-submitting voice input

    // MARK: - Dependencies

    let characterId: UUID
    let appDelegate: AppDelegate
    private let voiceSessionManager = VoiceSessionManager()

    // MARK: - Published State

    @Published var userInput = ""
    @Published var streamingResponse = ""
    @Published var isStreaming = false
    @Published var isThinking = false
    @Published var errorMessage: String?
    @Published var suggestedMessages: [String] = []
    @Published var showingClearConfirmation = false
    @Published var showingHabitProgress = false
    @Published var showingCelebration = false
    @Published var celebrationHabitName = ""
    @Published var celebrationStreak = 0
    @Published var scrollToBottom = false
    @Published var sessionStartMessageCount = 0
    @Published var skipContextUpdateOnClose = false
    @Published var shouldCloseWindow = false  // Triggers window close if character is deleted

    // Retry support
    private var lastAttemptedMessage: String = ""

    // Voice interaction
    @Published var isTTSEnabled = false

    // Context update debouncing
    private var lastContextUpdateTime: Date?
    private var lastContextUpdateMessageCount: Int = 0
    private var isUpdatingContext: Bool = false
    private static let contextUpdateInterval: TimeInterval = 300  // 5 minutes
    private static let contextUpdateMessageThreshold = 5  // Update after 5 new messages

    // MARK: - Initialization

    init(characterId: UUID, appDelegate: AppDelegate) {
        self.characterId = characterId
        self.appDelegate = appDelegate
    }

    // MARK: - Computed Properties (Voice Delegation)

    var isPushToTalkActive: Binding<Bool> {
        Binding(
            get: { self.voiceSessionManager.isPushToTalkActive },
            set: { self.voiceSessionManager.isPushToTalkActive = $0 }
        )
    }

    var showVoicePermissionAlert: Binding<Bool> {
        Binding(
            get: { self.voiceSessionManager.showVoicePermissionAlert },
            set: { self.voiceSessionManager.showVoicePermissionAlert = $0 }
        )
    }

    // MARK: - Computed Properties

    /// Returns the current character for this chat session
    ///
    /// **Defensive Pattern:** This property uses a guard-let pattern to handle the edge case
    /// where a character is deleted while its chat window is still open. If the character
    /// is not found, it returns a placeholder to prevent crashes, but the `validateCharacterExists()`
    /// method sets `shouldCloseWindow = true` to trigger graceful window closure.
    ///
    /// - Important: Always call `validateCharacterExists()` before performing critical operations
    ///   to ensure the character still exists in the character list.
    var currentCharacter: Character {
        guard let character = appDelegate.appState.characters.first(where: { $0.id == characterId }) else {
            LoggerService.chat.error("❌ Character not found with ID: \(self.characterId) - window should close")
            // Return a temporary placeholder - window will close via shouldCloseWindow flag
            // This prevents crashes while the window close animation completes
            return Character(name: "Error", masterPrompt: "", position: .zero)
        }
        return character
    }

    /// Validates that the character still exists in the character list
    ///
    /// This is a defensive check to handle the edge case where a user deletes a character
    /// while its chat window is still open. If the character is not found:
    /// 1. Sets `shouldCloseWindow = true` to trigger window closure
    /// 2. Returns `false` to signal that the operation should be aborted
    ///
    /// **Usage Pattern:**
    /// ```swift
    /// func performCriticalOperation() {
    ///     guard validateCharacterExists() else {
    ///         // Character was deleted, window will close automatically
    ///         return
    ///     }
    ///     // Safe to proceed with operation
    /// }
    /// ```
    ///
    /// - Returns: `true` if character exists, `false` if character was deleted
    private func validateCharacterExists() -> Bool {
        if appDelegate.appState.characters.first(where: { $0.id == characterId }) == nil {
            LoggerService.chat.error("❌ Character deleted - closing chat window")
            shouldCloseWindow = true
            return false
        }
        return true
    }

    var voiceSettings: VoiceSettings {
        appDelegate.appState.settings.voiceSettings
    }

    var effectiveVoiceIdentifier: String? {
        currentCharacter.customVoiceIdentifier ?? appDelegate.appState.settings.voiceSettings.voiceIdentifier
    }

    var effectiveSpeechRate: Float {
        currentCharacter.customSpeechRate ?? appDelegate.appState.settings.voiceSettings.speechRate
    }

    // MARK: - Model Auto-Switch

    /// Checks if character should switch from GPT-4.1 to GPT-4.1-mini after 10 messages
    ///
    /// This is a cost optimization: use the better model for initial interactions,
    /// then switch to the cheaper mini model once the character is established.
    ///
    /// **Conditions for switch:**
    /// - Auto-switch setting is enabled
    /// - Character has exactly 10 messages (5 exchanges)
    /// - Character has NO custom model set (respects user's explicit model choice)
    /// - Global default model is "gpt-4.1"
    /// - Sets customModel to "gpt-4.1-mini" to lock in the switch
    private func checkModelAutoSwitch() {
        // Check if auto-switch is enabled
        guard self.appDelegate.appState.settings.autoSwitchToMini else { return }

        let messageCount = self.currentCharacter.chatHistory.count

        // Only check at exactly 10 messages (after 5 exchanges)
        guard messageCount == 10 else { return }

        // IMPORTANT: Only auto-switch if character is using global default (no custom model)
        // If user explicitly set a custom model, respect their choice
        guard self.currentCharacter.customModel == nil else { return }

        // Check if global default is gpt-4.1
        guard self.appDelegate.appState.settings.globalAPIConfig.model == "gpt-4.1" else { return }

        // Switch to mini by setting custom model
        LoggerService.ai.info("🔄 Auto-switching '\(self.currentCharacter.name)' from gpt-4.1 to gpt-4.1-mini after 10 messages")
        updateCharacter { character in
            character.customModel = "gpt-4.1-mini"
        }
    }

    // MARK: - Character Updates

    /// Updates the current character with validation
    ///
    /// **Defensive Pattern:** This method validates that the character still exists before
    /// attempting any updates. If the character has been deleted, it aborts the operation
    /// and triggers window closure via `validateCharacterExists()`.
    ///
    /// **Error Handling:** Storage errors are logged and, for critical operations (clear history,
    /// context updates), displayed to the user via `errorMessage`.
    ///
    /// - Parameters:
    ///   - updater: Closure that modifies the character
    ///   - reason: Human-readable reason for the update (used in logs)
    func updateCharacter(_ updater: (inout Character) -> Void, reason: String = "unknown") {
        // Validate character exists before attempting update
        // If character was deleted, this sets shouldCloseWindow = true
        guard validateCharacterExists() else {
            LoggerService.storage.error("❌ Cannot update character - character no longer exists")
            return
        }

        if let index = appDelegate.appState.characters.firstIndex(where: { $0.id == characterId }) {
            LoggerService.storage.debug("📝 Updating character at index \(index) - Reason: \(reason)")
            updater(&appDelegate.appState.characters[index])

            let result = StorageService.shared.updateCharacter(appDelegate.appState.characters[index], in: &appDelegate.appState.settings)

            switch result {
            case .success:
                LoggerService.storage.info("💾 Character saved to disk - Reason: \(reason)")
            case .failure(let error):
                LoggerService.storage.error("❌ Failed to save character: \(error.localizedDescription)")
                // Show error to user for critical operations
                if reason.contains("CLEAR") || reason.contains("context") {
                    errorMessage = "Failed to save changes: \(error.localizedDescription)"
                }
            }
        } else {
            LoggerService.storage.error("❌ Failed to find character with ID: \(self.characterId)")
        }
    }

    // MARK: - Lifecycle

    func onAppear() {
        // Validate character exists - if not, window will close
        guard validateCharacterExists() else {
            return
        }

        // Initialize TTS state from current settings
        isTTSEnabled = voiceSettings.ttsEnabled

        // Record how many messages existed when we opened
        sessionStartMessageCount = currentCharacter.chatHistory.count

        // Trigger scroll to bottom after a delay to ensure view is fully loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.scrollDelay) {
            NotificationCenter.default.post(
                name: NSNotification.Name("ScrollChatToBottom"),
                object: self.characterId
            )
        }

        LoggerService.chat.info("💬 Chat session started for '\(self.currentCharacter.name)'")
        LoggerService.chat.debug("💬 Character ID: \(self.characterId)")
        LoggerService.chat.debug("💬 Existing messages: \(self.sessionStartMessageCount)")
        if sessionStartMessageCount > 0 {
            LoggerService.logUserContent("💬 First message", content: self.currentCharacter.chatHistory.first?.content ?? "N/A", category: LoggerService.chat)
        }

        // Clear notification badge when chat window opens
        if currentCharacter.hasNotification {
            updateCharacter({ $0.hasNotification = false }, reason: "clear notification badge")
            // Recreate widget to remove badge (async to avoid UI jank)
            Task { @MainActor in
                appDelegate.removeCharacterWidget(id: characterId)
                // Small delay to ensure clean removal before recreation
                try? await Task.sleep(nanoseconds: Self.widgetRecreationDelay)
                appDelegate.createCharacterWidget(for: currentCharacter)
            }
        }

        // Set initial suggestions if no chat history
        if currentCharacter.chatHistory.isEmpty {
            suggestedMessages = ["Hello!", "How are you?", "What can you help me with?"]
        }

        // If there's a pending activity, automatically trigger AI message
        if let pendingActivityId = currentCharacter.pendingActivityId,
           let activity = currentCharacter.activities.first(where: { $0.id == pendingActivityId }) {
            LoggerService.reminders.info("🔔 Auto-triggering AI message for pending activity: \(activity.name)")
            triggerActivityMessage(activity)
            updateCharacter({ $0.pendingActivityId = nil }, reason: "clear pending activity")
        }
    }

    func onDisappear() {
        // Cleanup voice resources when window disappears
        LoggerService.voice.debug("🔇 Chat window disappearing - cleaning up voice resources")
        voiceSessionManager.cleanup()
    }

    func handlePendingActivityChange(oldValue: UUID?, newValue: UUID?) {
        // Trigger activity message when a new pending activity is set (while window is already open)
        if let activityId = newValue, oldValue == nil,
           let activity = currentCharacter.activities.first(where: { $0.id == activityId }) {
            LoggerService.reminders.info("🔔 Pending activity detected while window open: \(activity.name)")
            triggerActivityMessage(activity)
            updateCharacter({ $0.pendingActivityId = nil }, reason: "clear pending activity after trigger")
        }
    }

    // MARK: - Clear History

    func clearHistory() {
        let messageCount = currentCharacter.chatHistory.count
        LoggerService.chat.info("🗑️ Clearing \(messageCount) messages from conversation history for \(self.currentCharacter.name)")
        LoggerService.chat.debug("Character ID: \(self.characterId)")

        // Clear chat history
        updateCharacter({ character in
            let beforeCount = character.chatHistory.count
            character.chatHistory.removeAll()
            let afterCount = character.chatHistory.count
            LoggerService.chat.debug("Before clear: \(beforeCount) messages")
            LoggerService.chat.debug("After clear: \(afterCount) messages")
        }, reason: "CLEAR HISTORY")

        // Verify immediately after save
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            LoggerService.storage.debug("🔍 Post-save verification: \(self.currentCharacter.chatHistory.count) messages in character")
            if let index = self.appDelegate.appState.characters.firstIndex(where: { $0.id == self.characterId }) {
                LoggerService.storage.debug("🔍 Verification from characters array: \(self.appDelegate.appState.characters[index].chatHistory.count) messages")
            }
        }

        // Clear suggested messages and set initial ones
        suggestedMessages = ["Hello!", "How are you?", "What can you help me with?"]

        // Reset session start count since we cleared everything
        sessionStartMessageCount = 0

        // Reset context update tracking
        lastContextUpdateMessageCount = 0
        lastContextUpdateTime = nil

        // Skip context update on close since we just cleared everything
        skipContextUpdateOnClose = true

        LoggerService.chat.info("✅ Conversation history cleared - context update tracking reset")
    }

    // MARK: - Send Message

    func sendMessage() {
        guard !userInput.isEmpty else { return }

        let message = userInput
        lastAttemptedMessage = message  // Store for retry
        userInput = ""
        errorMessage = nil

        // Clear suggestions when user sends a message
        suggestedMessages = []

        // Add user message to history
        let userMessage = Message(role: "user", content: message)
        updateCharacter({ $0.chatHistory.append(userMessage) }, reason: "user sent message")

        // Play send sound
        SoundEffects.shared.playMessageSent()

        // Trigger scroll to bottom
        scrollToBottom.toggle()

        // Get API config and use custom model if specified
        var config = appDelegate.appState.settings.globalAPIConfig
        if let customModel = currentCharacter.customModel {
            config.model = customModel
        }

        // Build context
        let messages = AIService.shared.buildContextMessages(
            for: currentCharacter,
            userMessage: message,
            messageHistoryCount: appDelegate.appState.settings.messageHistoryCount
        )

        // Debug: Log context being sent
        if !currentCharacter.persistentContext.isEmpty {
            LoggerService.logUserContent("📝 Current context being sent to AI", content: currentCharacter.persistentContext, category: LoggerService.ai)
        } else {
            LoggerService.ai.warning("⚠️ No current context available for \(self.currentCharacter.name)")
        }

        // Show thinking state first
        isThinking = true

        // Small delay to show thinking state
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.thinkingDelay) { [weak self] in
            guard let self = self else { return }

            // Start streaming
            self.isThinking = false
            self.isStreaming = true
            self.streamingResponse = ""

            AIService.shared.sendMessage(
                messages: messages,
                config: config,
                onChunk: { [weak self] chunk in
                    guard let self = self else { return }
                    self.streamingResponse += chunk
                },
                onComplete: { [weak self] in
                    guard let self = self else { return }
                    // Parse suggestions from response
                    let (cleanedResponse, suggestions) = self.parseSuggestions(from: self.streamingResponse)

                    // Parse habit markers from response
                    let (finalResponse, habitActions) = AIService.parseHabitMarkers(from: cleanedResponse)

                    // Process habit actions
                    let hasHabitCompletions = habitActions.contains(where: { $0.action == .complete })
                    if !habitActions.isEmpty {
                        self.processHabitActions(habitActions)
                    }

                    // Save assistant response (without suggestions or habit markers)
                    let assistantMessage = Message(role: "assistant", content: finalResponse)
                    self.updateCharacter { $0.chatHistory.append(assistantMessage) }

                    // Check if we should auto-switch to mini model
                    self.checkModelAutoSwitch()

                    // Set suggested messages for next interaction
                    self.suggestedMessages = suggestions

                    // Play received sound (skip if celebration will play)
                    if !hasHabitCompletions {
                        SoundEffects.shared.playMessageReceived()
                    }

                    // Speak response if TTS is enabled (but skip if celebration happening)
                    if self.voiceSettings.enabled && self.isTTSEnabled && !hasHabitCompletions {
                        self.voiceSessionManager.speak(
                            cleanedResponse,
                            voiceIdentifier: self.effectiveVoiceIdentifier,
                            rate: self.effectiveSpeechRate,
                            onComplete: {}
                        )
                    }

                    // Reset streaming state
                    self.streamingResponse = ""
                    self.isStreaming = false

                    // Trigger debounced context update after message is saved
                    self.debounceContextUpdate()
                },
                onError: { [weak self] error in
                    guard let self = self else { return }

                    self.errorMessage = error.localizedDescription
                    self.isStreaming = false
                    self.isThinking = false
                    self.streamingResponse = ""

                    // Restore the message to userInput for retry
                    self.userInput = self.lastAttemptedMessage

                    SoundEffects.shared.playError()
                }
            )
        }
    }

    // MARK: - Trigger Activity Message

    func triggerActivityMessage(_ activity: Activity) {
        errorMessage = nil

        // Get API config and use custom model if specified
        var config = appDelegate.appState.settings.globalAPIConfig
        if let customModel = currentCharacter.customModel {
            config.model = customModel
        }

        // Build context with activity
        let activityContext = activity.isTrackingEnabled
            ? "It's time for: \(activity.name) - \(activity.description)"
            : activity.name
        let messages = AIService.shared.buildContextMessages(
            for: currentCharacter,
            userMessage: "",
            reminderContext: activityContext,
            messageHistoryCount: appDelegate.appState.settings.messageHistoryCount
        )

        // Show thinking state first
        isThinking = true

        // Small delay to show thinking state
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.thinkingDelay) { [weak self] in
            guard let self = self else { return }

            // Start streaming
            self.isThinking = false
            self.isStreaming = true
            self.streamingResponse = ""

            AIService.shared.sendMessage(
                messages: messages,
                config: config,
                onChunk: { [weak self] chunk in
                    guard let self = self else { return }
                    self.streamingResponse += chunk
                },
                onComplete: { [weak self] in
                    guard let self = self else { return }
                    // Parse suggestions from response
                    let (cleanedResponse, suggestions) = self.parseSuggestions(from: self.streamingResponse)

                    // Parse habit markers from response
                    let (finalResponse, habitActions) = AIService.parseHabitMarkers(from: cleanedResponse)

                    // Process habit actions
                    let hasHabitCompletions = habitActions.contains(where: { $0.action == .complete })
                    if !habitActions.isEmpty {
                        self.processHabitActions(habitActions)
                    }

                    // Save assistant response (without suggestions or habit markers)
                    let assistantMessage = Message(role: "assistant", content: finalResponse)
                    self.updateCharacter { $0.chatHistory.append(assistantMessage) }

                    // Check if we should auto-switch to mini model
                    self.checkModelAutoSwitch()

                    // Set suggested messages for next interaction
                    self.suggestedMessages = suggestions

                    // Play received sound (skip if celebration will play)
                    if !hasHabitCompletions {
                        SoundEffects.shared.playMessageReceived()
                    }

                    // Speak response if TTS is enabled (but skip if celebration happening)
                    if self.voiceSettings.enabled && self.isTTSEnabled && !hasHabitCompletions {
                        self.voiceSessionManager.speak(
                            cleanedResponse,
                            voiceIdentifier: self.effectiveVoiceIdentifier,
                            rate: self.effectiveSpeechRate,
                            onComplete: {}
                        )
                    }

                    // Reset streaming state
                    self.streamingResponse = ""
                    self.isStreaming = false

                    // Trigger debounced context update after message is saved
                    self.debounceContextUpdate()
                },
                onError: { error in
                    self.errorMessage = error.localizedDescription
                    self.isStreaming = false
                    self.isThinking = false
                    self.streamingResponse = ""
                    SoundEffects.shared.playError()
                }
            )
        }
    }

    // MARK: - Update Persistent Context on Close

    func updatePersistentContextOnClose(completion: (() -> Void)? = nil) {
        // Skip if explicitly disabled (e.g., after clearing history)
        if skipContextUpdateOnClose {
            LoggerService.chat.debug("ℹ️ Skipping context update on close - explicitly disabled")
            skipContextUpdateOnClose = false // Reset for next time
            completion?()
            return
        }

        // Only update if there are NEW messages since last context update
        let messagesSinceLastUpdate = currentCharacter.chatHistory.count - lastContextUpdateMessageCount
        guard messagesSinceLastUpdate > 0 && !isStreaming && !isUpdatingContext else {
            if messagesSinceLastUpdate == 0 {
                LoggerService.chat.debug("ℹ️ Skipping context update on close - already up to date")
            } else if isStreaming {
                LoggerService.chat.debug("ℹ️ Skipping context update - currently streaming")
            } else if isUpdatingContext {
                LoggerService.chat.debug("ℹ️ Skipping context update - update already in progress")
            }
            // Call completion handler even if we skip the update
            completion?()
            return
        }

        LoggerService.chat.info("🧠 Final context update on close for \(self.currentCharacter.name)...")
        LoggerService.chat.debug("📊 \(messagesSinceLastUpdate) new message(s) since last update")

        // Mark as updating
        isUpdatingContext = true

        // Get API config
        var config = appDelegate.appState.settings.globalAPIConfig
        if let customModel = currentCharacter.customModel {
            config.model = customModel
        }

        // Update with messages since last update
        AIService.shared.updatePersistentContext(
            for: currentCharacter,
            messageHistoryCount: messagesSinceLastUpdate,
            config: config,
            onComplete: { [weak self] updatedContext in
                guard let self = self else {
                    completion?()
                    return
                }

                LoggerService.chat.info("✅ Final context updated on close for \(self.currentCharacter.name)")
                self.updateCharacter { $0.persistentContext = updatedContext }

                // Update tracking
                self.lastContextUpdateMessageCount = self.currentCharacter.chatHistory.count
                self.lastContextUpdateTime = Date()
                self.isUpdatingContext = false

                // Call completion handler after context is updated
                completion?()
            },
            onError: { [weak self] error in
                LoggerService.chat.error("❌ Failed to update current context: \(error.localizedDescription)")
                self?.isUpdatingContext = false
                // Silently fail - don't block window close
                // Still call completion handler even on error
                completion?()
            }
        )
    }

    // MARK: - Debounced Context Update

    /// Checks if context should be updated and triggers a background update if needed
    /// Debouncing strategy: Update if either 5 minutes have passed OR 5+ new messages
    func debounceContextUpdate() {
        // Skip if already updating or streaming
        guard !isUpdatingContext && !isStreaming else {
            LoggerService.chat.debug("⏸️ Skipping debounced update - \(self.isUpdatingContext ? "update in progress" : "streaming")")
            return
        }

        let currentMessageCount = currentCharacter.chatHistory.count
        let messagesSinceLastUpdate = currentMessageCount - lastContextUpdateMessageCount

        // Check if we should update based on time or message count
        let shouldUpdateByTime: Bool
        if let lastUpdate = lastContextUpdateTime {
            shouldUpdateByTime = Date().timeIntervalSince(lastUpdate) >= Self.contextUpdateInterval
        } else {
            shouldUpdateByTime = true // Never updated before
        }

        let shouldUpdateByMessageCount = messagesSinceLastUpdate >= Self.contextUpdateMessageThreshold

        guard shouldUpdateByTime || shouldUpdateByMessageCount else {
            let timeSinceUpdate = lastContextUpdateTime.map { Int(Date().timeIntervalSince($0)) } ?? 0
            LoggerService.chat.debug("⏸️ Context update not needed yet - \(messagesSinceLastUpdate) messages, \(timeSinceUpdate)s since last update")
            return
        }

        let reason = shouldUpdateByTime ? "5+ minutes elapsed" : "\(messagesSinceLastUpdate) new messages"
        LoggerService.chat.info("🔄 Triggering background context update (\(reason)) for \(self.currentCharacter.name)")

        // Mark as updating
        isUpdatingContext = true

        // Get API config
        var config = appDelegate.appState.settings.globalAPIConfig
        if let customModel = currentCharacter.customModel {
            config.model = customModel
        }

        // Update with messages since last update
        AIService.shared.updatePersistentContext(
            for: currentCharacter,
            messageHistoryCount: messagesSinceLastUpdate,
            config: config,
            onComplete: { [weak self] updatedContext in
                guard let self = self else { return }

                LoggerService.chat.info("✅ Background context updated for \(self.currentCharacter.name)")
                LoggerService.logUserContent("📝 Updated context", content: updatedContext, category: LoggerService.chat)

                self.updateCharacter { $0.persistentContext = updatedContext }

                // Update tracking
                self.lastContextUpdateMessageCount = self.currentCharacter.chatHistory.count
                self.lastContextUpdateTime = Date()
                self.isUpdatingContext = false
            },
            onError: { [weak self] error in
                LoggerService.chat.error("❌ Background context update failed: \(error.localizedDescription)")
                self?.isUpdatingContext = false
                // Silently fail - we'll try again later or on window close
            }
        )
    }

    // MARK: - Suggested Messages

    func sendSuggestedMessage(_ message: String) {
        userInput = message
        sendMessage()
    }

    func parseSuggestions(from response: String) -> (cleanedResponse: String, suggestions: [String]) {
        // Look for suggestions in format: [SUGGESTIONS: option1 | option2 | option3]
        // Case-insensitive to catch variations
        let pattern = #"\[SUGGESTIONS:([^\]]+)\]"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let nsRange = NSRange(response.startIndex..<response.endIndex, in: response)

        var suggestions: [String] = []
        var cleanedResponse = response

        if let match = regex?.firstMatch(in: response, options: [], range: nsRange),
           let suggestionRange = Range(match.range(at: 1), in: response) {
            // Extract suggestions
            let suggestionsText = String(response[suggestionRange])
            suggestions = suggestionsText
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            // Remove the suggestions marker from the response
            if let fullMatchRange = Range(match.range, in: response) {
                cleanedResponse = response.replacingCharacters(in: fullMatchRange, with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            LoggerService.chat.debug("💡 Parsed \(suggestions.count) suggestions: \(suggestions)")
        } else {
            LoggerService.chat.debug("ℹ️ No suggestions in response (AI chose not to include them)")
            LoggerService.chat.debug("   Likely reason: Open-ended question or letting user speak freely")
            LoggerService.logUserContent("   Last 100 chars", content: String(response.suffix(100)), category: LoggerService.chat)
        }

        return (cleanedResponse, suggestions)
    }

    // MARK: - Activity Actions

    func processHabitActions(_ actions: [HabitAction]) {
        LoggerService.habits.info("🎯 Processing \(actions.count) activity action(s)")

        for action in actions {
            // Find the activity (tracked activities only)
            guard let activityIndex = currentCharacter.activities.firstIndex(where: {
                $0.id == action.habitId && $0.isTrackingEnabled
            }) else {
                LoggerService.habits.warning("⚠️ Tracked activity not found with ID: \(action.habitId)")
                continue
            }

            var activity = currentCharacter.activities[activityIndex]

            switch action.action {
            case .complete:
                activity.markCompleted()
                LoggerService.habits.info("✅ Marked activity '\(activity.name)' as completed")

                // Trigger celebration animation
                triggerCelebration(for: activity)

            case .skip:
                activity.markSkipped()
                LoggerService.habits.info("⏭️ Marked activity '\(activity.name)' as skipped")
            }

            // Update the activity in the character
            updateCharacter { character in
                character.activities[activityIndex] = activity
            }
        }
    }

    func handleQuickHabitAction(habit: Activity, action: HabitAction.Action) {
        LoggerService.habits.debug("⚡️ Quick action: \(String(describing: action)) for activity '\(habit.name)'")

        // Update the activity
        guard let activityIndex = currentCharacter.activities.firstIndex(where: { $0.id == habit.id }) else {
            LoggerService.habits.warning("⚠️ Activity not found")
            return
        }

        var updatedActivity = currentCharacter.activities[activityIndex]

        switch action {
        case .complete:
            updatedActivity.markCompleted()
            LoggerService.habits.info("✅ Marked activity '\(updatedActivity.name)' as completed")

            // Trigger celebration
            triggerCelebration(for: updatedActivity)

        case .skip:
            updatedActivity.markSkipped()
            LoggerService.habits.info("⏭️ Marked activity '\(updatedActivity.name)' as skipped")
            SoundEffects.shared.playMessageReceived()
        }

        // Update the activity in the character
        updateCharacter { character in
            character.activities[activityIndex] = updatedActivity
        }
    }

    func triggerCelebration(for activity: Activity) {
        LoggerService.habits.info("🎉 Celebration! Activity completed: \(activity.name)")
        LoggerService.habits.info("🔥 Streak: \(activity.currentStreak) days")

        // Set celebration data
        celebrationHabitName = activity.name
        celebrationStreak = activity.currentStreak

        // Play celebration sound
        if activity.currentStreak == 1 || activity.currentStreak == 3 || activity.currentStreak == 7 ||
           activity.currentStreak == 14 || activity.currentStreak == 30 || activity.currentStreak % 50 == 0 {
            // Milestone sound
            SoundEffects.shared.playStreakMilestone()
        } else {
            // Regular celebration sound
            SoundEffects.shared.playCelebration()
        }

        // Show celebration overlay
        showingCelebration = true
    }

    // MARK: - Voice Interaction

    func toggleTTS() {
        // Toggle TTS on/off (persists globally)
        isTTSEnabled.toggle()
        LoggerService.voice.info("🔊 Toggling TTS to \(self.isTTSEnabled)")

        // Update global TTS setting so it persists
        appDelegate.appState.settings.voiceSettings.ttsEnabled = isTTSEnabled
        StorageService.shared.saveSettings(appDelegate.appState.settings)

        // Stop any current speech if we're muting
        if !isTTSEnabled {
            voiceSessionManager.stopSpeaking()
        }
    }

    func startPushToTalk() {
        voiceSessionManager.startPushToTalk(
            voiceSettings: voiceSettings,
            currentInput: userInput,
            onPartialTranscription: { [weak self] text in
                self?.userInput = text
            },
            onFinalTranscription: { [weak self] text in
                guard let self = self else { return }
                self.userInput = text

                // Automatically send if auto-submit is enabled
                if self.voiceSettings.autoSubmitAfterVoice {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Self.voiceAutoSubmitDelay) { [weak self] in
                        guard let self = self, !self.userInput.isEmpty else { return }
                        self.sendMessage()
                    }
                }
            }
        )
    }

    func stopPushToTalk() {
        voiceSessionManager.stopPushToTalk()
    }
}
