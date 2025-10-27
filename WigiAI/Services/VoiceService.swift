//
//  VoiceService.swift
//  WigiAI
//
//  Voice interaction service for speech-to-text and text-to-speech
//  EXPERIMENTAL FEATURE
//

import Foundation
import Speech
import AVFoundation
import Combine

import OSLog
#if canImport(AVKit)
import AVKit
#endif

/// Service for managing voice interactions with macOS native APIs
///
/// **Features:**
/// - **Speech-to-Text (STT)**: Push-to-talk with native macOS speech recognition
/// - **Text-to-Speech (TTS)**: Premium voice playback with 10 voice options
/// - **Zero-cost**: All processing happens locally on device
/// - **Privacy**: No data sent to external servers
///
/// **Voice Quality:**
/// - Supports macOS premium voices (enhanced quality)
/// - Automatic fallback to system voices if premium not installed
/// - Visual indicators for voice download status
///
/// **Permissions:**
/// - Speech recognition permission (first use prompt)
/// - Microphone access permission (required for STT)
/// - Automatic permission checking on init
///
/// **EXPERIMENTAL STATUS:**
/// This feature is fully functional but marked experimental because
/// voice download and permission flows can be confusing to users.
class VoiceService: NSObject, ObservableObject {
    /// Shared singleton instance
    static let shared = VoiceService()

    // MARK: - Published State

    /// Whether speech recognition is currently active
    @Published var isListening = false

    /// Whether text-to-speech playback is active
    @Published var isSpeaking = false

    /// Whether speech recognition permission has been granted
    @Published var hasSTTPermission = false

    /// Whether microphone access permission has been granted
    @Published var hasMicrophonePermission = false

    /// Current transcription text (updates in real-time during recognition)
    @Published var transcriptionText = ""

    // MARK: - Speech-to-Text (STT)

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var hasTapInstalled = false  // Track tap installation to prevent double-removal

    // MARK: - Text-to-Speech (TTS)

    private let synthesizer = AVSpeechSynthesizer()
    private var onSpeechFinished: (() -> Void)?

    // MARK: - Initialization

    private override init() {
        super.init()
        synthesizer.delegate = self
        checkPermissions()
    }

    // MARK: - Cleanup

    deinit {
        LoggerService.voice.info("🧹 Cleaning up VoiceService resources...")

        // Stop any ongoing speech recognition
        if isListening {
            stopListening()
        }

        // Stop any ongoing TTS
        if isSpeaking {
            stopSpeaking()
        }

        // Clear synthesizer delegate to break potential retain cycle
        synthesizer.delegate = nil

        LoggerService.voice.info("✅ VoiceService cleanup complete")
    }

    // MARK: - Permissions

    /// Checks current permission status for speech recognition and microphone
    ///
    /// Updates `hasSTTPermission` and `hasMicrophonePermission` properties.
    /// Called automatically on init.
    func checkPermissions() {
        // Check speech recognition authorization
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        self.hasSTTPermission = (speechStatus == .authorized)

        // Check microphone authorization separately
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        self.hasMicrophonePermission = (micStatus == .authorized)

        LoggerService.voice.info("🎤 Voice permissions - STT: \(self.hasSTTPermission), Mic: \(self.hasMicrophonePermission)")
    }

    /// Requests speech recognition and microphone permissions from the user
    ///
    /// - Parameter completion: Called with `true` if both permissions granted, `false` otherwise
    ///
    /// **Permission Flow:**
    /// 1. Requests microphone access (system dialog)
    /// 2. Requests speech recognition permission (system dialog)
    /// 3. Updates permission state
    /// 4. Calls completion handler
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        LoggerService.voice.info("🎤 Requesting voice permissions...")

        // First request microphone permission
        AVCaptureDevice.requestAccess(for: .audio) { micGranted in
            // Then request speech recognition permission
            SFSpeechRecognizer.requestAuthorization { [weak self] speechStatus in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.hasSTTPermission = (speechStatus == .authorized)
                    self.hasMicrophonePermission = micGranted
                    LoggerService.voice.info("🎤 Microphone auth: \(micGranted)")
                    LoggerService.voice.info("🎤 Speech recognition auth: \(speechStatus.rawValue)")

                    let hasAll = self.hasSTTPermission && self.hasMicrophonePermission
                    completion(hasAll)
                }
            }
        }
    }

    // MARK: - Speech-to-Text

    /// Starts listening for speech input (push-to-talk mode)
    ///
    /// - Parameters:
    ///   - onPartialResult: Optional callback for real-time transcription updates
    ///   - onFinalResult: Callback for final transcription when user stops speaking
    ///
    /// **Usage:**
    /// ```swift
    /// voiceService.startListening(
    ///     onPartialResult: { partial in print("Transcribing: \(partial)") },
    ///     onFinalResult: { final in self.messageText = final }
    /// )
    /// ```
    ///
    /// **Important:**
    /// - Requires both `hasSTTPermission` and `hasMicrophonePermission`
    /// - Automatically cancels any existing recognition task
    /// - Call `endListening()` when user releases push-to-talk button
    func startListening(onPartialResult: ((String) -> Void)? = nil, onFinalResult: @escaping (String) -> Void) {
        guard !isListening else {
            LoggerService.voice.warning("⚠️ Already listening")
            return
        }

        guard self.hasSTTPermission && self.hasMicrophonePermission else {
            LoggerService.voice.warning("⚠️ Missing permissions for speech recognition")
            LoggerService.voice.debug("   STT Permission: \(self.hasSTTPermission)")
            LoggerService.voice.debug("   Mic Permission: \(self.hasMicrophonePermission)")
            return
        }

        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        LoggerService.voice.info("🎤 Starting voice recognition...")
        LoggerService.voice.debug("   Speech recognizer available: \(self.speechRecognizer != nil)")
        LoggerService.voice.debug("   Speech recognizer locale: \(self.speechRecognizer?.locale.identifier ?? "unknown")")

        // Note: On macOS, audio session configuration is not needed
        // The AVAudioEngine handles audio routing automatically
        //
        // Expected system warnings in console (these are harmless):
        // - "AddInstanceForFactory: No factory registered" - Core Audio initialization
        // - "Query for com.apple.MobileAsset" - System checking for voice downloads
        // - "throwing -10877" - Audio unit initialization
        // These are macOS system-level logs and don't affect functionality

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            LoggerService.voice.error("❌ Unable to create recognition request")
            return
        }

        recognitionRequest.shouldReportPartialResults = true
        LoggerService.voice.info("✅ Recognition request created")

        // Get audio input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        LoggerService.voice.debug("🎙️ Microphone format: \(recordingFormat)")

        // Create recognition task
        recognitionTask = self.speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            var isFinal = false

            if let result = result {
                let transcription = result.bestTranscription.formattedString
                let confidence = result.bestTranscription.segments.first?.confidence ?? 0.0

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.transcriptionText = transcription

                    if result.isFinal {
                        isFinal = true
                        LoggerService.voice.info("🎤 Final transcription: '\(transcription)' (confidence: \(confidence))")
                        onFinalResult(transcription)
                    } else {
                        LoggerService.voice.info("🎤 Partial: '\(transcription)' (confidence: \(confidence))")
                        onPartialResult?(transcription)
                    }
                }
            }

            if let error = error {
                let nsError = error as NSError

                // Check if it's a "no speech detected" error (expected when user releases without speaking)
                let isNoSpeechError = nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1101
                let isNoSpeech = error.localizedDescription.lowercased().contains("no speech")

                if isNoSpeechError || isNoSpeech {
                    LoggerService.voice.debug("ℹ️ No speech detected (user released without speaking)")
                } else {
                    LoggerService.voice.error("❌ Speech recognition error: \(error.localizedDescription)")
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // Call final result with current text even if there was an error
                    if !self.transcriptionText.isEmpty {
                        onFinalResult(self.transcriptionText)
                    }
                    self.stopListening()
                }
            } else if isFinal {
                DispatchQueue.main.async { [weak self] in
                    self?.stopListening()
                }
            }
        }

        // Configure audio tap with level monitoring
        var audioLevelLogged = false
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)

            // Monitor audio levels (log once to verify mic is working)
            if !audioLevelLogged {
                let channelData = buffer.floatChannelData?[0]
                let frameLength = Int(buffer.frameLength)
                var sum: Float = 0.0
                if let data = channelData {
                    for i in 0..<frameLength {
                        sum += abs(data[i])
                    }
                }
                let average = sum / Float(frameLength)

                if average > 0.001 {
                    LoggerService.voice.debug("🎙️ Audio detected - level: \(String(format: "%.4f", average))")
                    audioLevelLogged = true
                } else if average > 0 {
                    LoggerService.voice.warning("⚠️ Very quiet audio - level: \(String(format: "%.6f", average)) - try speaking louder")
                    audioLevelLogged = true
                }
            }
        }
        hasTapInstalled = true  // Mark that we've installed a tap

        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
            transcriptionText = ""
            LoggerService.voice.info("🎤 Started listening")
        } catch {
            LoggerService.voice.error("❌ Audio engine failed to start: \(error)")
            // Clean up tap if engine failed to start
            if hasTapInstalled {
                inputNode.removeTap(onBus: 0)
                hasTapInstalled = false
            }
        }
    }

    /// Signals end of speech input and waits for final transcription
    ///
    /// Call this when user releases push-to-talk button. The service will
    /// stop recording audio but wait for the final transcription result before
    /// calling `stopListening()`.
    ///
    /// **Timeout:** Automatically cleans up after 2 seconds if final result doesn't arrive.
    func endListening() {
        // Signal that we're done recording but let recognition finish
        guard isListening else { return }

        LoggerService.voice.info("🎤 Ending audio input (waiting for final transcription)...")

        // Stop audio engine and remove tap
        audioEngine.stop()

        // Only remove tap if one was installed
        if hasTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasTapInstalled = false
        }

        // Signal end of audio to get final result
        recognitionRequest?.endAudio()

        // Set a timeout to clean up if final result never arrives
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            if self.isListening {
                LoggerService.voice.warning("⚠️ Voice recognition timeout - forcing cleanup")
                self.stopListening()
            }
        }
    }

    /// Immediately stops listening and cleans up speech recognition resources
    ///
    /// This is called automatically by `endListening()` after receiving final result.
    /// Can also be called directly to cancel speech recognition.
    func stopListening() {
        guard isListening else { return }

        LoggerService.voice.info("🎤 Stopped listening")

        // Stop audio engine if it's running
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        // Only remove tap if one was installed
        if hasTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasTapInstalled = false
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isListening = false
    }

    // MARK: - Text-to-Speech

    /// Speaks text using macOS text-to-speech with specified voice
    ///
    /// - Parameters:
    ///   - text: Text to speak (emojis automatically removed)
    ///   - voiceIdentifier: Optional voice ID (e.g., "com.apple.voice.premium.en-US.Zoe")
    ///   - rate: Speech rate (0.0 = slowest, 1.0 = fastest, default: 0.52 for clarity)
    ///   - onFinished: Optional callback when speech completes
    ///
    /// **Voice Fallback Order:**
    /// 1. Specified `voiceIdentifier` (if available)
    /// 2. First available premium voice
    /// 3. Any enhanced quality voice
    /// 4. Default system voice
    ///
    /// **Behavior:**
    /// - Automatically stops any ongoing speech before starting
    /// - Emojis are removed for better pronunciation
    /// - Empty text (or emoji-only) is silently ignored
    func speak(_ text: String, voiceIdentifier: String? = nil, rate: Float = 0.52, onFinished: (() -> Void)? = nil) {
        guard !text.isEmpty else { return }

        // Stop any current speech
        if isSpeaking {
            stopSpeaking()
        }

        self.onSpeechFinished = onFinished

        // Remove emojis from text before speaking
        let cleanedText = removeEmojis(from: text)
        guard !cleanedText.isEmpty else {
            LoggerService.voice.debug("ℹ️ Text only contains emojis, skipping speech")
            return
        }

        let utterance = AVSpeechUtterance(string: cleanedText)

        // Get best available voice (with fallback logic)
        let selectedVoice = getBestAvailableVoice(preferredIdentifier: voiceIdentifier)

        // Log which voice we're actually using (only in debug)
        if let requestedId = voiceIdentifier, requestedId != selectedVoice.identifier {
            LoggerService.voice.warning("⚠️ Requested voice '\(requestedId)' not available")
            LoggerService.voice.info("✅ Using fallback: \(selectedVoice.name)")
        } else if voiceIdentifier != nil {
            LoggerService.voice.info("🔊 Using selected voice: \(selectedVoice.name)")
        }
        // Don't log when no preference - reduces console noise

        utterance.voice = selectedVoice
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        isSpeaking = true
        synthesizer.speak(utterance)

        LoggerService.voice.info("🔊 Speaking: \(text.prefix(50))...")
    }

    /// Immediately stops any ongoing text-to-speech playback
    func stopSpeaking() {
        guard isSpeaking else { return }

        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        onSpeechFinished = nil

        LoggerService.voice.info("🔊 Stopped speaking")
    }

    // MARK: - Available Voices

    /// Retrieves all available English voices on the system
    ///
    /// - Returns: Sorted array of English voices available for TTS
    func getAvailableVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { $0.name < $1.name }
    }

    /// Retrieves list of premium voices with installation status
    ///
    /// - Returns: Array of tuples containing voice identifier, display name, and installation status
    ///
    /// **Premium Voices (10 total):**
    /// - 6 US English voices (Ava, Evan, Joelle, Nathan, Noel, Zoe)
    /// - 3 UK English voices (Fiona, Malcolm, Stephanie)
    /// - 1 Australian English voice (Matilda)
    ///
    /// **Note:** If no premium voices are installed, includes default Samantha as fallback
    func getPremiumVoices() -> [(identifier: String, name: String, isInstalled: Bool)] {
        let premiumVoices = [
            // US English
            ("com.apple.voice.premium.en-US.Ava", "Ava (US Female)"),
            ("com.apple.voice.premium.en-US.Evan", "Evan (US Male)"),
            ("com.apple.voice.premium.en-US.Joelle", "Joelle (US Female)"),
            ("com.apple.voice.premium.en-US.Nathan", "Nathan (US Male)"),
            ("com.apple.voice.premium.en-US.Noel", "Noel (US Male)"),
            ("com.apple.voice.premium.en-US.Zoe", "Zoe (US Female)"),
            // UK English
            ("com.apple.voice.premium.en-GB.Fiona", "Fiona (Scottish Female)"),
            ("com.apple.voice.premium.en-GB.Malcolm", "Malcolm (British Male)"),
            ("com.apple.voice.premium.en-GB.Stephanie", "Stephanie (British Female)"),
            // Australian English
            ("com.apple.voice.premium.en-AU.Matilda", "Matilda (Australian Female)")
        ]

        // Check which voices are actually installed
        let installedVoices = Set(AVSpeechSynthesisVoice.speechVoices().map { $0.identifier })

        var voices = premiumVoices.map { (identifier, name) in
            let isInstalled = installedVoices.contains(identifier)
            return (identifier, name, isInstalled)
        }

        // If no premium voices are installed, add default fallback
        let hasPremiumInstalled = voices.contains(where: { $0.2 })  // $0.2 is isInstalled
        if !hasPremiumInstalled {
            voices.append(("com.apple.voice.compact.en-US.Samantha", "Samantha (Default Fallback)", true))
        }

        return voices
    }

    /// Checks if any premium voices are installed on the system
    ///
    /// - Returns: `true` if at least one premium voice is installed
    func hasPremiumVoiceInstalled() -> Bool {
        let premiumVoices = getPremiumVoices()
        return premiumVoices.filter { $0.0.contains("premium") }.contains(where: { $0.2 })  // $0.0 is identifier, $0.2 is isInstalled
    }

    /// Checks if a specific voice is installed
    ///
    /// - Parameter voiceIdentifier: Voice identifier to check
    /// - Returns: `true` if voice is available for use
    func isVoiceInstalled(_ voiceIdentifier: String) -> Bool {
        return AVSpeechSynthesisVoice(identifier: voiceIdentifier) != nil &&
               AVSpeechSynthesisVoice.speechVoices().contains(where: { $0.identifier == voiceIdentifier })
    }

    /// Gets the best available voice with intelligent fallback
    ///
    /// - Parameter preferredIdentifier: Optional preferred voice identifier
    /// - Returns: Voice to use (never fails, always returns a valid voice)
    ///
    /// **Fallback Strategy:**
    /// 1. Requested voice (if available)
    /// 2. First premium voice in priority list
    /// 3. Any enhanced quality English voice
    /// 4. Default en-US voice
    /// 5. First available voice (ultimate fallback)
    func getBestAvailableVoice(preferredIdentifier: String?) -> AVSpeechSynthesisVoice {
        // Try preferred voice first
        if let identifier = preferredIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice
        }

        // Try premium voices in priority order (matching getPremiumVoices list)
        let premiumPriority = [
            // US English
            "com.apple.voice.premium.en-US.Ava",
            "com.apple.voice.premium.en-US.Evan",
            "com.apple.voice.premium.en-US.Joelle",
            "com.apple.voice.premium.en-US.Nathan",
            "com.apple.voice.premium.en-US.Noel",
            "com.apple.voice.premium.en-US.Zoe",
            // UK English
            "com.apple.voice.premium.en-GB.Fiona",
            "com.apple.voice.premium.en-GB.Malcolm",
            "com.apple.voice.premium.en-GB.Stephanie",
            // Australian English
            "com.apple.voice.premium.en-AU.Matilda"
        ]

        for voiceId in premiumPriority {
            if let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
                return voice
            }
        }

        // Try to find any enhanced quality voice
        if let enhancedVoice = AVSpeechSynthesisVoice.speechVoices().first(where: {
            $0.language.hasPrefix("en") && $0.quality == .enhanced
        }) {
            return enhancedVoice
        }

        // Final fallback to default system voice
        // This should never fail as en-US is always available, but handle gracefully just in case
        if let fallbackVoice = AVSpeechSynthesisVoice(language: "en-US") {
            return fallbackVoice
        }

        // Ultimate fallback - return any available voice
        LoggerService.voice.warning("⚠️ Critical: en-US voice not available, using first available voice")
        return AVSpeechSynthesisVoice.speechVoices().first ?? AVSpeechSynthesisVoice()
    }

    func getRecommendedVoices() -> [AVSpeechSynthesisVoice] {
        let recommended = [
            "com.apple.voice.compact.en-US.Samantha",
            "com.apple.eloquence.en-US.Rocko",
            "com.apple.voice.premium.en-US.Zoe",
            "com.apple.voice.compact.en-GB.Daniel",
            "com.apple.eloquence.en-US.Eddy"
        ]

        return recommended.compactMap { id in
            AVSpeechSynthesisVoice(identifier: id)
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isSpeaking = false
            self.onSpeechFinished?()
            self.onSpeechFinished = nil
            LoggerService.voice.info("🔊 Finished speaking")
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isSpeaking = false
            self.onSpeechFinished = nil
            LoggerService.voice.info("🔊 Speech cancelled")
        }
    }

    // MARK: - Helper Functions

    /// Remove emojis from text for better TTS pronunciation
    private func removeEmojis(from text: String) -> String {
        return text.filter { character in
            // Keep if not an emoji
            !character.unicodeScalars.contains { scalar in
                // Emoji ranges
                (0x1F600...0x1F64F).contains(scalar.value) ||  // Emoticons
                (0x1F300...0x1F5FF).contains(scalar.value) ||  // Misc Symbols and Pictographs
                (0x1F680...0x1F6FF).contains(scalar.value) ||  // Transport and Map
                (0x2600...0x26FF).contains(scalar.value) ||    // Misc symbols
                (0x2700...0x27BF).contains(scalar.value) ||    // Dingbats
                (0xFE00...0xFE0F).contains(scalar.value) ||    // Variation Selectors
                (0x1F900...0x1F9FF).contains(scalar.value) ||  // Supplemental Symbols and Pictographs
                (0x1F1E6...0x1F1FF).contains(scalar.value)     // Flags
            }
        }
    }
}
