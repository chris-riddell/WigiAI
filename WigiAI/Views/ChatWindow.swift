//
//  ChatWindow.swift
//  WigiAI
//
//  Main chat window orchestrator
//

import SwiftUI
import Speech
import OSLog

@MainActor
struct ChatWindow: View {
    let characterId: UUID
    let appDelegate: AppDelegate
    @Binding var isPresented: Bool

    // ViewModel handles all state and business logic
    @StateObject private var viewModel: ChatViewModel

    // Voice service for observation
    @ObservedObject private var voiceService = VoiceService.shared

    // Keyboard event monitors (view-specific - to prevent memory leaks)
    @State private var keyDownMonitor: Any?
    @State private var keyUpMonitor: Any?

    init(characterId: UUID, appDelegate: AppDelegate, isPresented: Binding<Bool>) {
        self.characterId = characterId
        self.appDelegate = appDelegate
        _isPresented = isPresented
        _viewModel = StateObject(wrappedValue: ChatViewModel(characterId: characterId, appDelegate: appDelegate))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ChatHeaderView(
                character: viewModel.currentCharacter,
                characterId: characterId,
                appDelegate: appDelegate,
                messageCount: viewModel.currentCharacter.chatHistory.count,
                isTTSEnabled: viewModel.isTTSEnabled,
                voiceEnabled: viewModel.voiceSettings.enabled,
                showingHabitProgress: $viewModel.showingHabitProgress,
                showingClearConfirmation: $viewModel.showingClearConfirmation,
                onToggleTTS: viewModel.toggleTTS,
                onOpenSettings: {
                    appDelegate.openCharacters(selectedCharacter: characterId)
                },
                onClose: {
                    LoggerService.ui.debug("🔄 Close button pressed")
                    if let window = NSApplication.shared.windows.first(where: {
                        ($0 as? ChatPanel)?.characterId == viewModel.currentCharacter.id
                    }) {
                        window.close()
                    }
                }
            )

            Divider()

            // Messages
            MessageListView(
                messages: viewModel.currentCharacter.chatHistory,
                isThinking: viewModel.isThinking,
                isStreaming: viewModel.isStreaming,
                streamingResponse: viewModel.streamingResponse,
                characterId: characterId,
                characterName: viewModel.currentCharacter.name,
                scrollToBottomTrigger: viewModel.scrollToBottom
            )
            .onChange(of: viewModel.suggestedMessages) {
                // Scroll to bottom when suggestions appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ScrollChatToBottom"),
                            object: characterId
                        )
                    }
                }
            }

            Divider()

            // Input area
            ChatInputView(
                userInput: $viewModel.userInput,
                errorMessage: $viewModel.errorMessage,
                suggestedMessages: viewModel.suggestedMessages,
                isStreaming: viewModel.isStreaming,
                characterName: viewModel.currentCharacter.name,
                voiceEnabled: viewModel.voiceSettings.enabled,
                sttEnabled: viewModel.voiceSettings.sttEnabled,
                isPushToTalkActive: viewModel.isPushToTalkActive,
                voiceService: voiceService,
                onSendMessage: viewModel.sendMessage,
                onStartPushToTalk: viewModel.startPushToTalk,
                onStopPushToTalk: viewModel.stopPushToTalk,
                onSendSuggestion: viewModel.sendSuggestedMessage
            )
        }
        .overlay {
            // Celebration overlay
            if viewModel.showingCelebration {
                CelebrationView(
                    habitName: viewModel.celebrationHabitName,
                    streak: viewModel.celebrationStreak,
                    isPresented: $viewModel.showingCelebration
                )
            }
        }
        .onAppear {
            viewModel.onAppear()

            // Set up keyboard shortcuts and store monitors to prevent memory leaks
            keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event -> NSEvent? in
                // ⌘W to close window
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
                    isPresented = false
                    return nil
                }
                // Escape to close window
                if event.keyCode == 53 { // Escape key
                    isPresented = false
                    return nil
                }

                // Enter to send message, Shift+Enter for newline
                if event.keyCode == 36 { // Enter/Return key
                    if event.modifierFlags.contains(.shift) {
                        // Shift+Enter - allow newline (return event to be processed)
                        return event
                    } else {
                        // Plain Enter - send message
                        if !self.viewModel.userInput.isEmpty {
                            self.viewModel.sendMessage()
                        }
                        return nil // Consume the event
                    }
                }

                // Spacebar for push-to-talk (when voice enabled and text field is empty)
                if event.keyCode == 49 && // Spacebar
                   self.viewModel.voiceSettings.enabled &&
                   self.viewModel.voiceSettings.sttEnabled &&
                   self.viewModel.userInput.isEmpty { // Only when not typing
                    if !self.viewModel.isPushToTalkActive.wrappedValue {
                        self.viewModel.startPushToTalk()
                        LoggerService.voice.debug("⌨️ Spacebar push-to-talk started")
                    }
                    return nil // Consume the event
                }

                return event
            }

            keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event -> NSEvent? in
                // Spacebar release for push-to-talk
                if event.keyCode == 49 && // Spacebar
                   self.viewModel.isPushToTalkActive.wrappedValue {
                    LoggerService.voice.debug("⌨️ Spacebar push-to-talk stopped")
                    self.viewModel.stopPushToTalk()
                    return nil // Consume the event
                }
                return event
            }
        }
        .onChange(of: viewModel.currentCharacter.pendingActivityId) { oldValue, newValue in
            viewModel.handlePendingActivityChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: viewModel.shouldCloseWindow) { _, shouldClose in
            if shouldClose {
                LoggerService.chat.warning("⚠️ Character deleted - closing window")
                isPresented = false
            }
        }
        .onDisappear {
            viewModel.onDisappear()

            // CRITICAL: Remove keyboard event monitors to prevent memory leaks
            cleanupKeyboardMonitors()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ChatWindowWillClose"))) { notification in
            // Check if this notification is for this character
            if let characterId = notification.userInfo?["characterId"] as? UUID,
               characterId == self.characterId {
                LoggerService.chat.debug("🔔 Received window close notification - triggering final context update")

                // Safety: Remove keyboard monitors early as backup to onDisappear
                cleanupKeyboardMonitors()

                // Trigger final context update (non-blocking - will complete in background)
                // This will only update if there are new messages since last background update
                viewModel.updatePersistentContextOnClose()
            }
        }
        .alert("Clear Conversation History", isPresented: $viewModel.showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                viewModel.clearHistory()
            }
        } message: {
            Text("This will delete all chat messages. The character's personality and current context will be preserved.")
        }
        .alert("Voice Permissions Required", isPresented: viewModel.showVoicePermissionAlert) {
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("WigiAI needs microphone and speech recognition permissions to use voice features. Please grant access in System Settings → Privacy & Security.")
        }
    }

    // MARK: - Keyboard Monitor Cleanup

    private func cleanupKeyboardMonitors() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
            LoggerService.ui.debug("🧹 Removed keyDown monitor")
        }
        if let monitor = keyUpMonitor {
            NSEvent.removeMonitor(monitor)
            keyUpMonitor = nil
            LoggerService.ui.debug("🧹 Removed keyUp monitor")
        }
    }
}
