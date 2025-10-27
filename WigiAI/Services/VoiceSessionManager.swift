//
//  VoiceSessionManager.swift
//  WigiAI
//
//  Manages voice interaction sessions (speech-to-text and text-to-speech)
//

import Foundation
import Speech
import OSLog
import Combine

/// Manages voice interaction sessions for chat windows
///
/// This manager was extracted from `ChatViewModel` to separate voice interaction
/// concerns from chat logic (~150 lines reduction in ChatViewModel).
///
/// **Responsibilities:**
/// - Push-to-talk session management
/// - Permission checking and error handling
/// - Text appending (voice input adds to existing text)
/// - TTS playback coordination
///
/// **Key Feature:** Appends voice input to existing text rather than replacing it,
/// allowing users to type part of a message and complete it with voice.
@MainActor
class VoiceSessionManager: ObservableObject {
    // MARK: - Published State

    /// Whether push-to-talk is currently active (user holding button)
    @Published var isPushToTalkActive = false

    /// Whether to show voice permission denied alert
    @Published var showVoicePermissionAlert = false

    // MARK: - Dependencies

    private let voiceService = VoiceService.shared

    // MARK: - State

    /// Stores text that existed before voice input started (for appending)
    private var textBeforeVoiceInput = ""

    // MARK: - Voice Input

    /// Starts push-to-talk session
    /// - Parameters:
    ///   - voiceSettings: Current voice settings
    ///   - currentInput: Current text in input field
    ///   - onPartialTranscription: Called with partial transcription results
    ///   - onFinalTranscription: Called with final transcription result
    func startPushToTalk(
        voiceSettings: VoiceSettings,
        currentInput: String,
        onPartialTranscription: @escaping (String) -> Void,
        onFinalTranscription: @escaping (String) -> Void
    ) {
        guard voiceSettings.enabled && voiceSettings.sttEnabled else { return }

        // Check permission status
        let authStatus = SFSpeechRecognizer.authorizationStatus()

        switch authStatus {
        case .authorized:
            // Permission granted - start listening
            actuallyStartListening(
                currentInput: currentInput,
                onPartialTranscription: onPartialTranscription,
                onFinalTranscription: onFinalTranscription
            )

        case .notDetermined:
            // First time - request permission (macOS will show system dialog)
            voiceService.requestPermissions { [weak self] success in
                guard let self = self else { return }

                if success {
                    self.actuallyStartListening(
                        currentInput: currentInput,
                        onPartialTranscription: onPartialTranscription,
                        onFinalTranscription: onFinalTranscription
                    )
                }
            }

        case .denied, .restricted:
            // Permission was denied - show our alert to guide user to Settings
            showVoicePermissionAlert = true

        @unknown default:
            LoggerService.voice.warning("⚠️ Unknown speech recognition authorization status")
        }
    }

    private func actuallyStartListening(
        currentInput: String,
        onPartialTranscription: @escaping (String) -> Void,
        onFinalTranscription: @escaping (String) -> Void
    ) {
        isPushToTalkActive = true

        // Save existing text so we can append to it
        textBeforeVoiceInput = currentInput

        voiceService.startListening(
            onPartialResult: { [weak self] transcription in
                guard let self = self else { return }

                // Append to existing text in real-time
                if self.textBeforeVoiceInput.isEmpty {
                    onPartialTranscription(transcription)
                } else {
                    onPartialTranscription(self.textBeforeVoiceInput + " " + transcription)
                }
            },
            onFinalResult: { [weak self] transcription in
                guard let self = self else { return }

                // Ignore very short transcriptions (likely noise or accidental trigger)
                let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.count < 3 {
                    LoggerService.voice.debug("ℹ️ Ignoring short transcription: '\(trimmed)' (likely background noise)")
                    onFinalTranscription(self.textBeforeVoiceInput)
                    self.isPushToTalkActive = false
                    return
                }

                // Append final transcription to existing text
                if self.textBeforeVoiceInput.isEmpty {
                    onFinalTranscription(transcription)
                } else {
                    onFinalTranscription(self.textBeforeVoiceInput + " " + transcription)
                }
                self.isPushToTalkActive = false
            }
        )

        LoggerService.voice.info("🎤 Started push-to-talk (appending to existing text)")
    }

    /// Stops push-to-talk session
    func stopPushToTalk() {
        isPushToTalkActive = false
        voiceService.endListening()
        LoggerService.voice.info("🎤 Stopped push-to-talk")
    }

    // MARK: - Voice Output

    /// Speaks text using configured voice
    /// - Parameters:
    ///   - text: Text to speak
    ///   - voiceIdentifier: Optional voice identifier override
    ///   - rate: Speech rate
    ///   - onComplete: Called when speech completes
    func speak(
        _ text: String,
        voiceIdentifier: String?,
        rate: Float,
        onComplete: @escaping () -> Void
    ) {
        guard !text.isEmpty else { return }

        LoggerService.voice.debug("🔊 Speaking with voice ID: \(voiceIdentifier ?? "nil (using default)")")

        voiceService.speak(text, voiceIdentifier: voiceIdentifier, rate: rate) {
            LoggerService.voice.debug("🔊 Finished speaking")
            onComplete()
        }
    }

    /// Stops any ongoing speech
    func stopSpeaking() {
        voiceService.stopSpeaking()
    }

    // MARK: - Cleanup

    /// Cleanup resources when session ends
    func cleanup() {
        stopSpeaking()
        if isPushToTalkActive {
            stopPushToTalk()
        }
    }
}
