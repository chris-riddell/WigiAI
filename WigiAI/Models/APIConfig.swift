//
//  APIConfig.swift
//  WigiAI
//
//  AI Companion Desktop Widget
//

import Foundation

/// Configuration for OpenAI-compatible API connections
///
/// Supports OpenAI, Ollama, and other compatible API endpoints.
/// API keys are stored securely in Keychain, not in the JSON file.
struct APIConfig: Codable, Equatable, Hashable {
    /// Base URL for the API endpoint (e.g., "https://api.openai.com/v1")
    var apiURL: String

    /// Legacy API key field (always empty - keys stored in Keychain)
    ///
    /// This field exists only for backwards compatibility and is never populated.
    /// Use `actualAPIKey` to retrieve the key from Keychain.
    var apiKey: String

    /// Model identifier (e.g., "gpt-4o", "gpt-3.5-turbo")
    var model: String

    /// Whether to use Server-Sent Events (SSE) streaming for responses
    var useStreaming: Bool

    /// Controls response randomness and creativity
    ///
    /// Valid range: 0.0 (deterministic) to 2.0 (very creative)
    /// Default: 0.7 (balanced)
    var temperature: Double

    enum CodingKeys: String, CodingKey {
        case apiURL
        case apiKey
        case model
        case useStreaming
        case temperature
    }

    // MARK: - Keychain Integration

    /// Retrieves the actual API key from secure Keychain storage
    ///
    /// - Returns: The API key string, or empty string if not set
    var actualAPIKey: String {
        KeychainService.shared.loadAPIKey() ?? ""
    }

    /// Checks if a valid API key exists in Keychain
    ///
    /// - Returns: `true` if a non-empty API key is stored
    var hasAPIKey: Bool {
        if let key = KeychainService.shared.loadAPIKey(), !key.isEmpty {
            return true
        }
        return false
    }

    /// Saves API key to secure Keychain storage
    ///
    /// - Parameter key: The API key to store (empty string to delete)
    /// - Note: The `apiKey` property is always cleared to ensure keys aren't saved to JSON
    mutating func setAPIKey(_ key: String) {
        // Clear the JSON field (should always be empty)
        self.apiKey = ""

        // Save to Keychain
        if key.isEmpty {
            KeychainService.shared.deleteAPIKey()
        } else {
            KeychainService.shared.saveAPIKey(key)
        }
    }

    /// Default API configuration (OpenAI with GPT-4o)
    static var defaultConfig: APIConfig {
        APIConfig(
            apiURL: "https://api.openai.com/v1",
            apiKey: "",
            model: "gpt-4o",
            useStreaming: true,
            temperature: 0.7
        )
    }

    init(apiURL: String, apiKey: String, model: String, useStreaming: Bool, temperature: Double = 0.7) {
        self.apiURL = apiURL
        self.apiKey = apiKey
        self.model = model
        self.useStreaming = useStreaming
        self.temperature = temperature
    }

    // Backward compatibility - default to streaming enabled and temperature 0.7
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apiURL = try container.decode(String.self, forKey: .apiURL)
        apiKey = try container.decode(String.self, forKey: .apiKey)
        model = try container.decode(String.self, forKey: .model)
        useStreaming = try container.decodeIfPresent(Bool.self, forKey: .useStreaming) ?? true
        temperature = try container.decodeIfPresent(Double.self, forKey: .temperature) ?? 0.7
    }
}
