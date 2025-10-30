//
//  AppSettings.swift
//  WigiAI
//
//  AI Companion Desktop Widget
//

import Foundation

/// Global application settings
///
/// Stores app-wide configuration including API settings, character references,
/// and feature preferences. Character data is stored separately in individual files.
struct AppSettings: Codable {
    /// Whether the app launches automatically at system startup
    var launchOnStartup: Bool

    /// Default API configuration for all characters
    ///
    /// Individual characters can override with their own custom settings
    var globalAPIConfig: APIConfig

    /// List of character UUIDs (character data stored in separate files)
    ///
    /// Full character objects are loaded from `~/Library/Application Support/WigiAI/characters/{UUID}.json`
    var characterIds: [UUID]

    /// Number of recent messages to include in AI context
    ///
    /// Default: 10 messages
    var messageHistoryCount: Int

    /// Whether automatic updates via Sparkle are enabled
    var autoUpdateEnabled: Bool

    /// Whether the user has completed initial onboarding
    var hasCompletedOnboarding: Bool

    /// Global voice interaction settings
    var voiceSettings: VoiceSettings

    /// Whether to automatically switch from gpt-4.1 to gpt-4.1-mini after 10 messages
    ///
    /// Default: true (cost optimization)
    var autoSwitchToMini: Bool

    enum CodingKeys: String, CodingKey {
        case launchOnStartup
        case globalAPIConfig
        case characterIds
        case messageHistoryCount
        case autoUpdateEnabled
        case hasCompletedOnboarding
        case voiceSettings
        case autoSwitchToMini
    }

    /// Default application settings for new installations
    static var defaultSettings: AppSettings {
        AppSettings(
            launchOnStartup: false,
            globalAPIConfig: APIConfig.defaultConfig,
            characterIds: [],
            messageHistoryCount: 10,
            autoUpdateEnabled: true,
            hasCompletedOnboarding: false,
            voiceSettings: VoiceSettings(),
            autoSwitchToMini: true
        )
    }

    init(launchOnStartup: Bool, globalAPIConfig: APIConfig, characterIds: [UUID], messageHistoryCount: Int, autoUpdateEnabled: Bool = true, hasCompletedOnboarding: Bool = false, voiceSettings: VoiceSettings = VoiceSettings(), autoSwitchToMini: Bool = true) {
        self.launchOnStartup = launchOnStartup
        self.globalAPIConfig = globalAPIConfig
        self.characterIds = characterIds
        self.messageHistoryCount = messageHistoryCount
        self.autoUpdateEnabled = autoUpdateEnabled
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.voiceSettings = voiceSettings
        self.autoSwitchToMini = autoSwitchToMini
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        launchOnStartup = try container.decode(Bool.self, forKey: .launchOnStartup)
        globalAPIConfig = try container.decode(APIConfig.self, forKey: .globalAPIConfig)
        characterIds = try container.decodeIfPresent([UUID].self, forKey: .characterIds) ?? []
        messageHistoryCount = try container.decodeIfPresent(Int.self, forKey: .messageHistoryCount) ?? 10
        autoUpdateEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoUpdateEnabled) ?? true
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        voiceSettings = try container.decodeIfPresent(VoiceSettings.self, forKey: .voiceSettings) ?? VoiceSettings()
        autoSwitchToMini = try container.decodeIfPresent(Bool.self, forKey: .autoSwitchToMini) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(launchOnStartup, forKey: .launchOnStartup)
        try container.encode(globalAPIConfig, forKey: .globalAPIConfig)
        try container.encode(characterIds, forKey: .characterIds)
        try container.encode(messageHistoryCount, forKey: .messageHistoryCount)
        try container.encode(autoUpdateEnabled, forKey: .autoUpdateEnabled)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encode(voiceSettings, forKey: .voiceSettings)
        try container.encode(autoSwitchToMini, forKey: .autoSwitchToMini)
    }
}

// MARK: - Voice Settings

/// Voice interaction configuration for text-to-speech and speech-to-text
///
/// Can be overridden per-character using character-specific voice settings.
struct VoiceSettings: Codable, Hashable, Equatable {
    /// Master toggle for all voice features
    var enabled: Bool

    /// Whether AI responses should be read aloud (text-to-speech)
    var ttsEnabled: Bool

    /// Whether voice input is available (speech-to-text)
    var sttEnabled: Bool

    /// Whether voice input should automatically send messages
    var autoSubmitAfterVoice: Bool

    /// macOS voice identifier for text-to-speech
    ///
    /// Example: "com.apple.voice.premium.en-US.Zoe"
    var voiceIdentifier: String?

    /// Speech playback speed (0.0 to 1.0)
    ///
    /// Default: 0.52 (slightly slower than normal for clarity)
    var speechRate: Float

    init(enabled: Bool = false, ttsEnabled: Bool = true, sttEnabled: Bool = true, autoSubmitAfterVoice: Bool = false, voiceIdentifier: String? = "com.apple.voice.premium.en-US.Zoe", speechRate: Float = 0.52) {
        self.enabled = enabled
        self.ttsEnabled = ttsEnabled
        self.sttEnabled = sttEnabled
        self.autoSubmitAfterVoice = autoSubmitAfterVoice
        self.voiceIdentifier = voiceIdentifier
        self.speechRate = speechRate
    }
}
