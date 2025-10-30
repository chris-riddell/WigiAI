//
//  AIService.swift
//  WigiAI
//
//  AI Companion Desktop Widget
//

import Foundation
import OSLog

/// Service for managing AI interactions with OpenAI-compatible APIs
///
/// **Core Responsibilities:**
/// - Send messages to AI with streaming or non-streaming responses
/// - Build optimized context from character data (prompt caching support)
/// - Update and maintain persistent context summaries
/// - Parse habit tracking markers from AI responses
/// - Handle API errors and network issues
///
/// **Optimizations:**
/// - OpenAI prompt caching for 50% cost reduction
/// - Incremental context updates (preserves existing information)
/// - Thread-safe streaming with proper resource management
/// - Comprehensive API key validation
///
/// **Streaming Architecture:**
/// - Reusable URLSession prevents memory leaks
/// - Thread-safe data handling via dispatch queue
/// - Server-Sent Events (SSE) parsing
class AIService: NSObject, ObservableObject {
    /// Shared singleton instance
    static let shared = AIService()

    // MARK: - Constants

    /// Timeout for API requests in seconds
    private static let requestTimeout: TimeInterval = 60.0

    /// Conservative temperature for context updates (prevents creativity in summarization)
    private static let contextUpdateTemperature: Double = 0.3

    /// Maximum time to wait for streaming data before considering it stalled (seconds)
    private static let streamingStallTimeout: TimeInterval = 30.0

    private var streamingTask: URLSessionDataTask?

    // Thread-safe data access (prevents race conditions)
    private let dataQueue = DispatchQueue(label: "com.wigiai.aiservice.data", qos: .userInitiated)
    private var _receivedData = Data()
    private var receivedData: Data {
        get { dataQueue.sync { _receivedData } }
        set { dataQueue.sync { _receivedData = newValue } }
    }

    private var onChunkCallback: ((String) -> Void)?
    private var onCompleteCallback: (() -> Void)?
    private var onErrorCallback: ((Error) -> Void)?
    private var currentModel: String = ""

    // Thread-safe error tracking
    private let errorQueue = DispatchQueue(label: "com.wigiai.aiservice.error", qos: .userInitiated)
    private var _hasReportedError = false
    private var hasReportedError: Bool {
        get { errorQueue.sync { _hasReportedError } }
        set { errorQueue.sync { _hasReportedError = newValue } }
    }

    // Streaming stall detection
    private var streamingStallTimer: Timer?
    private var lastChunkReceivedTime: Date?

    // Reusable URLSession for streaming (prevents memory leaks)
    private lazy var streamingSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    private override init() {
        super.init()
    }

    // MARK: - Cleanup

    /// Cancels any ongoing streaming request and resets state
    ///
    /// Call this when closing a chat window or when the user wants to stop
    /// an in-progress AI response.
    func cancelStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        receivedData = Data()
        stopStreamingStallTimer()
        hasReportedError = false
        lastChunkReceivedTime = nil
    }

    /// Cleanup resources (called when service is being deallocated)
    deinit {
        streamingSession.invalidateAndCancel()
        stopStreamingStallTimer()
    }

    // MARK: - Streaming Stall Detection

    /// Starts a timer to detect when streaming has stalled (no data received for too long)
    private func startStreamingStallTimer() {
        stopStreamingStallTimer()  // Clear any existing timer
        lastChunkReceivedTime = Date()

        streamingStallTimer = Timer.scheduledTimer(withTimeInterval: Self.streamingStallTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            // Check if we've received any chunks recently
            if let lastChunk = self.lastChunkReceivedTime {
                let timeSinceLastChunk = Date().timeIntervalSince(lastChunk)
                if timeSinceLastChunk >= Self.streamingStallTimeout {
                    LoggerService.ai.error("❌ Streaming stalled - no data received for \(Int(timeSinceLastChunk)) seconds")
                    self.handleStreamingError(AIServiceError.timeout)
                }
            }
        }
    }

    /// Stops the streaming stall detection timer
    private func stopStreamingStallTimer() {
        streamingStallTimer?.invalidate()
        streamingStallTimer = nil
    }

    /// Resets the stall timer (call whenever a chunk is received)
    private func resetStreamingStallTimer() {
        lastChunkReceivedTime = Date()
    }

    /// Handles streaming errors consistently
    /// - Parameter error: The error that occurred
    private func handleStreamingError(_ error: Error) {
        guard !hasReportedError else {
            LoggerService.ai.debug("⏸️ Error already reported, skipping duplicate")
            return
        }

        hasReportedError = true
        stopStreamingStallTimer()

        LoggerService.ai.error("❌ Streaming error: \(error.localizedDescription)")

        DispatchQueue.main.async { [weak self] in
            self?.onErrorCallback?(error)
        }
    }

    // MARK: - Request Building

    /// Builds a URLRequest for API calls (shared between streaming and non-streaming)
    private func buildRequest(
        url: URL,
        messages: [Message],
        config: APIConfig,
        streaming: Bool
    ) throws -> URLRequest {
        // Prepare request body
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": streaming,
            "temperature": config.temperature
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw AIServiceError.invalidRequest
        }

        // Log sanitized request (without sensitive data)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            LoggerService.ai.debug("📤 API Request Body (sanitized):")
            LoggerService.ai.debug("\(self.sanitizeRequestLog(jsonString), privacy: .public)")
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.actualAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = Self.requestTimeout

        return request
    }

    // MARK: - Send Message (Streaming or Non-Streaming)

    /// Sends messages to the AI API with streaming or non-streaming response
    ///
    /// - Parameters:
    ///   - messages: Array of messages including system prompt, context, and conversation
    ///   - config: API configuration (URL, key, model, temperature, streaming preference)
    ///   - onChunk: Callback for each chunk of response text (called multiple times for streaming)
    ///   - onComplete: Callback when response is fully received
    ///   - onError: Callback if request fails with error details
    ///
    /// **Usage:**
    /// ```swift
    /// AIService.shared.sendMessage(
    ///     messages: messages,
    ///     config: apiConfig,
    ///     onChunk: { text in self.displayText += text },
    ///     onComplete: { self.saveMessage() },
    ///     onError: { error in self.showError(error) }
    /// )
    /// ```
    func sendMessage(
        messages: [Message],
        config: APIConfig,
        onChunk: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        // Validate API configuration
        guard !config.actualAPIKey.isEmpty else {
            LoggerService.ai.error("❌ API Error: API key is empty. Please configure in Settings → API Settings")
            onError(AIServiceError.missingAPIKey)
            return
        }

        guard !config.apiURL.isEmpty else {
            LoggerService.ai.error("❌ API Error: API URL is empty. Please configure in Settings → API Settings")
            onError(AIServiceError.invalidURL)
            return
        }

        // Validate API key format
        do {
            try validateAPIKey(config.actualAPIKey, apiURL: config.apiURL)
        } catch {
            LoggerService.ai.error("❌ API key validation failed: \(error.localizedDescription)")
            onError(error)
            return
        }

        let fullURL = "\(config.apiURL)/chat/completions"
        LoggerService.ai.info("🔗 Connecting to: \(fullURL)")
        LoggerService.ai.debug("🤖 Using model: \(config.model)")
        LoggerService.ai.debug("📡 Streaming: \(config.useStreaming ? "enabled" : "disabled")")

        guard let url = URL(string: fullURL) else {
            LoggerService.ai.error("❌ API Error: Invalid URL format - \(fullURL)")
            onError(AIServiceError.invalidURL)
            return
        }

        // Use non-streaming mode if disabled
        if !config.useStreaming {
            sendMessageNonStreaming(url: url, messages: messages, config: config, onChunk: onChunk, onComplete: onComplete, onError: onError)
            return
        }

        // Store callbacks and current model
        self.onChunkCallback = onChunk
        self.onCompleteCallback = onComplete
        self.onErrorCallback = onError
        self.receivedData = Data()
        self.currentModel = config.model
        self.hasReportedError = false

        // Build request using shared method
        let request: URLRequest
        do {
            request = try buildRequest(url: url, messages: messages, config: config, streaming: true)
        } catch {
            LoggerService.ai.error("❌ Failed to build request: \(error.localizedDescription)")
            onError(error as? AIServiceError ?? .invalidRequest)
            return
        }

        // Use reusable streaming session (prevents memory leaks)
        streamingTask = streamingSession.dataTask(with: request)
        streamingTask?.resume()

        // Start stall detection timer
        startStreamingStallTimer()
        LoggerService.ai.debug("⏱️ Started streaming stall timer (\(Self.streamingStallTimeout)s timeout)")
    }

    // MARK: - Send Message Non-Streaming

    private func sendMessageNonStreaming(
        url: URL,
        messages: [Message],
        config: APIConfig,
        onChunk: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        // Build request using shared method
        let request: URLRequest
        do {
            request = try buildRequest(url: url, messages: messages, config: config, streaming: false)
        } catch {
            LoggerService.ai.error("❌ Failed to build request: \(error.localizedDescription)")
            onError(error as? AIServiceError ?? .invalidRequest)
            return
        }

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // Note: AIService is a singleton, but using [weak self] is still good practice
            // to prevent potential retain cycles with completion handlers
            guard self != nil else { return }

            if let error = error {
                LoggerService.ai.error("❌ URLSession error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    onError(error)
                }
                return
            }

            // Check HTTP status
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 400 {
                    LoggerService.ai.error("❌ HTTP Error: Status code \(httpResponse.statusCode)")
                    let errorMessage: String
                    switch httpResponse.statusCode {
                    case 400:
                        errorMessage = "Bad request. The model '\(config.model)' may not exist or the request is invalid."
                    case 401:
                        errorMessage = "Authentication failed. Please check your API key."
                    case 403:
                        errorMessage = "Access forbidden. Your API key may not have permission."
                    case 404:
                        errorMessage = "API endpoint not found. Please check your API URL."
                    case 429:
                        errorMessage = "Rate limit exceeded. Please try again later."
                    case 500...599:
                        errorMessage = "Server error (\(httpResponse.statusCode)). Please try again later."
                    default:
                        errorMessage = "HTTP error \(httpResponse.statusCode)"
                    }
                    let error = NSError(domain: "AIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                    DispatchQueue.main.async {
                        onError(error)
                    }
                    return
                } else {
                    LoggerService.ai.info("✅ HTTP \(httpResponse.statusCode) - Received non-streaming response")
                }
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    onError(AIServiceError.noData)
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {

                    LoggerService.ai.info("✅ Received complete response")

                    // Simulate streaming by sending the whole message at once
                    DispatchQueue.main.async {
                        onChunk(content)
                        onComplete()
                    }
                } else {
                    DispatchQueue.main.async {
                        onError(AIServiceError.noData)
                    }
                }
            } catch {
                LoggerService.ai.error("❌ JSON parsing error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    onError(error)
                }
            }
        }

        task.resume()
    }

    // MARK: - Build Context Messages

    /// Builds optimized message array for API requests with prompt caching support
    ///
    /// **Message Structure (optimized for OpenAI caching):**
    /// 1. **System message** - Character's master prompt (cached, rarely changes)
    /// 2. **Assistant message** - Persistent context + habit status (updated independently)
    /// 3. **Recent history** - Last N messages from conversation
    /// 4. **User message** - Current user input (may include reminder context)
    ///
    /// - Parameters:
    ///   - character: Character whose context to build
    ///   - userMessage: Current message from user
    ///   - reminderContext: Optional reminder text if triggered by notification
    ///   - messageHistoryCount: Number of recent messages to include (default: 10)
    /// - Returns: Optimized array of messages ready for API request
    ///
    /// **Optimizations:**
    /// - System prompt stays pure for OpenAI caching (50% cost savings)
    /// - Context in assistant message allows independent updates
    /// - Habit status injected separately to avoid invalidating cache
    func buildContextMessages(
        for character: Character,
        userMessage: String,
        reminderContext: String? = nil,
        messageHistoryCount: Int = 10
    ) -> [Message] {
        var messages: [Message] = []

        // OPTIMIZATION: System prompt stays pure (better for OpenAI prompt caching)
        // This rarely changes, so it will be cached by OpenAI for 50% cost savings
        var systemPrompt = character.masterPrompt

        // Add chat context and formatting instructions
        systemPrompt += """


COMMUNICATION STYLE:
This is a chat window interface. Be conversational and aim for brief, punchy responses that get straight to the point.

However, prioritize being SMART and HELPFUL over being short:
- If more context makes your response clearer or more useful, include it
- Show awareness of the conversation history and the user's situation
- Provide enough detail to demonstrate understanding and expertise
- Don't be artificially brief when a thoughtful explanation would be better

In short: Be concise by default, but never sacrifice quality, clarity, or helpfulness for brevity.
"""

        // Add instructions for suggested responses (at END for recency bias)
        systemPrompt += """


SUGGESTED QUICK REPLIES:
When appropriate, end your response with 2-3 suggested quick replies for the user.

Format: [SUGGESTIONS: reply1 | reply2 | reply3]

When to include:
- ✅ When asking questions with clear answer options
- ✅ When user might want to follow up on specific topics
- ✅ When there are natural next steps
- ❌ Skip if asking open-ended questions where suggestions would feel limiting

Guidelines:
- Keep each suggestion SHORT (3-6 words maximum)
- Make them natural and conversational
- Relevant to the context of your response

Example 1 (specific question):
"That's a great goal! What's your timeline?"
[SUGGESTIONS: Within 3 months | By end of year | Not sure yet]

Example 2 (natural follow-ups):
"I can help with habit tracking, motivation, or just chat."
[SUGGESTIONS: Track my habits | Need motivation | Just chatting]

Example 3 (open-ended - NO suggestions):
"Tell me more about what's on your mind today."
(No suggestions here - letting them speak freely)
"""

        // Add habit tracking instructions if character has tracked activities
        let trackedActivities = character.activities.filter { $0.isTrackingEnabled && $0.isEnabled }
        if !trackedActivities.isEmpty {
            systemPrompt += """


HABIT TRACKING SYSTEM:
You have access to a habit tracking system. The user has configured habits they want to track.

**IMPORTANT: When you see habits marked as "⏳ Pending (due today)" in your context, this means:**
- The user has NOT YET completed or skipped this habit today
- You SHOULD ask them about it naturally during the conversation
- Don't assume they've done it - ask if they've completed it or if they're planning to

To mark a habit as complete or skipped, respond with a structured format:
- [HABIT_COMPLETE: activity-uuid] - Mark activity as completed for today
- [HABIT_SKIP: activity-uuid] - Mark activity as skipped for today

Guidelines:
- Check the HABIT TRACKING STATUS in your context to see which habits are pending today
- Ask naturally during check-ins or when the user mentions related activities
- If a habit shows "⏳ Pending", proactively ask about it: "Have you done [habit] today?"
- Don't be pushy - if they haven't done it yet, be encouraging
- Celebrate completions and acknowledge progress (especially streaks!)
- The system will handle the tracking automatically
- Only use these markers when the user explicitly confirms completion or skipping

Example conversations:
User: "I just finished my morning run!"
You: "Awesome! Great job on completing your exercise. [HABIT_COMPLETE: 123e4567-e89b-12d3-a456-426614174000] How did it feel?"

You see habit is pending:
You: "Hey! I see you haven't logged your meditation yet today. Have you had a chance to do it?"
"""
        }

        messages.append(Message(role: "system", content: systemPrompt))

        // OPTIMIZATION: Move context to assistant message (Option B)
        // This allows the system prompt to be cached independently
        // Context changes don't invalidate the cached system prompt
        var contextContent = ""

        if !character.persistentContext.isEmpty {
            contextContent = "Here's what I know about our relationship and your goals:\n\n\(character.persistentContext)"
        }

        // Add habit tracking status if there are tracked activities
        if !trackedActivities.isEmpty {
            if !contextContent.isEmpty {
                contextContent += "\n\n"
            }
            contextContent += "HABIT TRACKING STATUS:\n"

            let calendar = Calendar.current
            let today = Date()

            for activity in trackedActivities {
                let status: String

                if activity.isCompletedOn(date: today) {
                    status = "✅ Completed today"
                } else if activity.isSkippedOn(date: today) {
                    status = "⏭️ Skipped today"
                } else if activity.isDueOn(date: today) {
                    status = "⏳ Pending (due today) - ASK ABOUT THIS!"
                } else {
                    status = "Not due today"
                }

                var habitInfo = "• \(activity.name): \(activity.description) - \(status)"
                if activity.currentStreak > 0 {
                    habitInfo += " (🔥 \(activity.currentStreak) day streak)"
                }

                // Add last 7 days history for context
                habitInfo += "\n  Last 7 days: "
                var historySymbols: [String] = []
                for dayOffset in (0..<7).reversed() {
                    if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                        if activity.isCompletedOn(date: date) {
                            historySymbols.append("✅")
                        } else if activity.isSkippedOn(date: date) {
                            historySymbols.append("⏭")
                        } else if activity.isDueOn(date: date) {
                            historySymbols.append("⬜")
                        } else {
                            historySymbols.append("·")
                        }
                    }
                }
                habitInfo += historySymbols.joined(separator: " ")
                habitInfo += " (✅=done, ⏭=skipped, ⬜=missed, ·=not due)"

                habitInfo += "\n  UUID: \(activity.id.uuidString)"

                contextContent += "\n\(habitInfo)"
            }
        }

        if !contextContent.isEmpty {
            messages.append(Message(role: "assistant", content: contextContent))
        }

        // Add recent chat history (configurable count)
        let recentHistory = Array(character.chatHistory.suffix(messageHistoryCount))
        messages.append(contentsOf: recentHistory)

        // Build the user message
        var finalUserMessage = userMessage

        // If this is a reminder trigger, make it explicit to the AI
        if let reminder = reminderContext, !reminder.isEmpty {
            if userMessage.isEmpty {
                // Reminder-triggered message: tell AI to proactively engage
                finalUserMessage = "[REMINDER TRIGGERED: \(reminder)] - Please reach out to me about this reminder in a natural, conversational way based on your personality and our relationship."
            } else {
                // User sent a message while reminder is active
                finalUserMessage = "[REMINDER: \(reminder)]\n\n\(userMessage)"
            }
        }

        // Add current user message
        messages.append(Message(role: "user", content: finalUserMessage))

        // Debug logging - show what's being sent
        LoggerService.ai.debug("============================================================")
        LoggerService.ai.debug("🔍 CONTEXT STRUCTURE SENT TO AI:")
        LoggerService.logUserContent("System Prompt (cached)", content: character.masterPrompt, category: LoggerService.ai)
        if !character.persistentContext.isEmpty {
            LoggerService.logUserContent("Context (assistant msg)", content: character.persistentContext, category: LoggerService.ai)
        } else {
            LoggerService.ai.debug("⚠️ NO CURRENT CONTEXT")
        }
        LoggerService.ai.debug("Recent history count: \(recentHistory.count)")
        LoggerService.ai.debug("Total messages: \(messages.count)")
        LoggerService.ai.debug("============================================================")

        return messages
    }

    // MARK: - Update Persistent Context

    /// Updates character's persistent context summary using AI
    ///
    /// Creates an incremental summary that preserves existing context and adds new
    /// information from recent conversation. Uses conservative temperature (0.3) to
    /// prevent AI from being overly creative with removing or changing context.
    ///
    /// - Parameters:
    ///   - character: Character whose context to update
    ///   - messageHistoryCount: Number of recent messages to merge into context
    ///   - config: API configuration for the summarization request
    ///   - onComplete: Callback with updated context string
    ///   - onError: Callback if summarization fails
    ///
    /// **Strategy:**
    /// - INCREMENTAL updates (not replacements)
    /// - DEFAULT to keeping existing context
    /// - ONLY remove context if explicitly contradicted
    /// - No length limits (completeness over brevity)
    func updatePersistentContext(
        for character: Character,
        messageHistoryCount: Int,
        config: APIConfig,
        onComplete: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        // Build a summary request
        var messages: [Message] = []

        // Get the recent conversation
        let recentHistory = Array(character.chatHistory.suffix(messageHistoryCount))

        // Log what we're working with
        LoggerService.ai.info("📝 CONTEXT UPDATE:")
        LoggerService.ai.debug("   Existing context length: \(character.persistentContext.count) characters")
        LoggerService.ai.debug("   New messages to merge: \(messageHistoryCount)")
        LoggerService.ai.debug("   Using temperature: 0.3 (conservative)")

        // Create a system prompt for summarization
        let summaryPrompt = """
        You are helping to maintain a current context summary for an AI character.

        EXISTING CURRENT CONTEXT (preserve this unless outdated):
        \(character.persistentContext.isEmpty ? "None yet." : character.persistentContext)

        Your task: MERGE the recent conversation below with the existing context by:
        1. KEEP ALL existing context that is still relevant (do NOT remove information unless it's outdated or contradicted)
        2. ADD new important information from the conversation (goals, preferences, facts, progress, decisions, etc.)
        3. UPDATE any context items that have changed (e.g., "started 2 weeks ago" → "started 3 weeks ago")
        4. ONLY remove context if it's explicitly contradicted or clearly outdated

        CRITICAL RULES:
        - This is an INCREMENTAL UPDATE, not a replacement or summary
        - DEFAULT TO KEEPING existing context - when in doubt, preserve it
        - Do NOT remove context just to be "brief" - completeness is more important than brevity
        - If the conversation doesn't mention an existing topic, KEEP that topic in the context
        - Only REMOVE context if it's directly contradicted by new information
        - There is NO length limit - include all relevant information

        Format as bullet points with sub-bullets for details:
        • Main topic or category
          - Specific details, dates, preferences
          - Progress updates, goals, or metrics

        Example format:
        • User prefers morning check-ins
        • Working on exercise goals (started 2 weeks ago)
          - Completed 3 workouts this week
          - Target: 5 workouts per week
          - Enjoys running and strength training
        • Interested in productivity techniques
          - Currently using Pomodoro method
          - Wants to improve focus during work hours

        Return ONLY the merged bullet point context, nothing else. Do not include explanations or commentary.
        """

        messages.append(Message(role: "system", content: summaryPrompt))

        // Add the conversation history
        messages.append(Message(role: "user", content: "Recent conversation:\n\n" + recentHistory.map { "\($0.role): \($0.content)" }.joined(separator: "\n\n")))

        // Make a non-streaming request to get the updated context
        guard let url = URL(string: "\(config.apiURL)/chat/completions") else {
            onError(AIServiceError.invalidURL)
            return
        }

        // Use lower temperature for context updates to be more conservative/deterministic
        // This prevents the AI from being too creative with removing or changing existing context
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": false,
            "temperature": Self.contextUpdateTemperature  // Lower than user's setting - more conservative for context preservation
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            onError(AIServiceError.invalidRequest)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.actualAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 60

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // Note: AIService is a singleton, but using [weak self] is still good practice
            // to prevent potential retain cycles with completion handlers
            guard self != nil else { return }

            if let error = error {
                DispatchQueue.main.async {
                    onError(error)
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    onError(AIServiceError.noData)
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    let updatedContext = content.trimmingCharacters(in: .whitespacesAndNewlines)

                    // Log the result
                    LoggerService.ai.info("✅ CONTEXT UPDATE COMPLETE:")
                    LoggerService.ai.debug("   Old length: \(character.persistentContext.count) chars")
                    LoggerService.ai.debug("   New length: \(updatedContext.count) chars")
                    LoggerService.ai.debug("   Change: \(updatedContext.count - character.persistentContext.count) chars")

                    DispatchQueue.main.async {
                        onComplete(updatedContext)
                    }
                } else {
                    DispatchQueue.main.async {
                        onError(AIServiceError.noData)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    onError(error)
                }
            }
        }

        task.resume()
    }
}

// MARK: - URLSessionDataDelegate

extension AIService: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Reset stall timer - we received data
        resetStreamingStallTimer()

        receivedData.append(data)

        // Convert to string and parse SSE events
        guard let newString = String(data: data, encoding: .utf8) else {
            LoggerService.ai.warning("⚠️ Failed to decode chunk data as UTF-8 - chunk may be corrupted or incomplete")
            // Don't treat this as fatal - continue processing other chunks
            return
        }

        let lines = newString.components(separatedBy: "\n")
        for line in lines {
            guard line.hasPrefix("data: ") else { continue }

            let jsonString = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)

            // Check for [DONE] marker
            if jsonString == "[DONE]" {
                LoggerService.ai.info("✅ Stream completed successfully")
                stopStreamingStallTimer()
                DispatchQueue.main.async { [weak self] in
                    self?.onCompleteCallback?()
                }
                return
            }

            // Parse JSON chunk
            guard let jsonData = jsonString.data(using: .utf8) else {
                LoggerService.ai.debug("⏭️ Skipping non-UTF8 chunk")
                continue
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let delta = firstChoice["delta"] as? [String: Any],
                      let content = delta["content"] as? String else {
                    // Silently skip non-content chunks (like finish_reason chunks)
                    continue
                }

                DispatchQueue.main.async { [weak self] in
                    self?.onChunkCallback?(content)
                }
            } catch {
                LoggerService.ai.warning("⚠️ Failed to parse streaming chunk JSON: \(error.localizedDescription)")
                // Continue processing other chunks rather than failing entirely
                continue
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Always stop the stall timer when stream completes (success or failure)
        stopStreamingStallTimer()

        if let error = error {
            // Map NSError to AIServiceError for better user-facing messages
            let aiError: AIServiceError
            let nsError = error as NSError

            // Check if this is a cancellation (user-initiated stop)
            if nsError.code == NSURLErrorCancelled {
                LoggerService.ai.debug("ℹ️ Streaming cancelled by user")
                return
            }

            if nsError.code == NSURLErrorTimedOut {
                aiError = .timeout
            } else if nsError.code == NSURLErrorNotConnectedToInternet || nsError.code == NSURLErrorNetworkConnectionLost {
                aiError = .networkError("No internet connection")
            } else if nsError.code == NSURLErrorCannotFindHost || nsError.code == NSURLErrorCannotConnectToHost {
                aiError = .networkError("Cannot reach server")
            } else {
                aiError = .networkError(error.localizedDescription)
            }

            // Use centralized error handler
            handleStreamingError(aiError)
        }
        // Don't log successful completion to reduce noise
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let httpResponse = response as? HTTPURLResponse {
            // Only log status code, not all headers
            if httpResponse.statusCode >= 400 {
                LoggerService.ai.error("❌ HTTP Error: Status code \(httpResponse.statusCode)")
            } else {
                LoggerService.ai.info("✅ HTTP \(httpResponse.statusCode) - Streaming response...")
            }

            // Check for HTTP error status codes
            if httpResponse.statusCode >= 400 {
                // Map to appropriate AIServiceError
                let error: AIServiceError
                switch httpResponse.statusCode {
                case 400:
                    error = .modelNotFound
                case 401:
                    error = .unauthorized
                case 403:
                    error = .unauthorized
                case 404:
                    error = .invalidURL
                case 429:
                    error = .rateLimitExceeded
                case 500...599:
                    error = .serverError(httpResponse.statusCode)
                default:
                    error = .serverError(httpResponse.statusCode)
                }

                // Use centralized error handler
                handleStreamingError(error)

                // Cancel the task since we have an error
                dataTask.cancel()
            }
        }
        completionHandler(.allow)
    }

    // MARK: - Request Log Sanitization

    /// Sanitizes request logs by redacting sensitive information
    /// - Parameter requestLog: The raw request JSON string
    /// - Returns: Sanitized version safe for logging
    private func sanitizeRequestLog(_ requestLog: String) -> String {
        var sanitized = requestLog

        // Redact message content to avoid logging user data
        // Replace content values with placeholders while preserving structure
        let contentPattern = #""content"\s*:\s*"[^"]*""#
        if let regex = try? NSRegularExpression(pattern: contentPattern, options: []) {
            let nsString = sanitized as NSString
            let matches = regex.matches(in: sanitized, options: [], range: NSRange(location: 0, length: nsString.length))
            // Process in reverse to avoid index shifting
            for match in matches.reversed() {
                if let range = Range(match.range, in: sanitized) {
                    sanitized.replaceSubrange(range, with: #""content":"<redacted>""#)
                }
            }
        }

        return sanitized
    }

    // MARK: - Habit Marker Parsing

    /// Parses habit tracking markers from AI response text
    ///
    /// Extracts `[HABIT_COMPLETE: uuid]` and `[HABIT_SKIP: uuid]` markers that the AI
    /// uses to indicate habit tracking actions. Removes markers from text and returns
    /// clean display text along with parsed actions.
    ///
    /// - Parameter text: Raw AI response text (may contain habit markers)
    /// - Returns: Tuple of (cleaned text for display, array of habit actions to process)
    ///
    /// **Supported Markers:**
    /// - `[HABIT_COMPLETE: <uuid>]` - Mark habit as completed
    /// - `[HABIT_SKIP: <uuid>]` - Mark habit as skipped
    static func parseHabitMarkers(from text: String) -> (cleanedText: String, habitActions: [HabitAction]) {
        var cleanedText = text
        var habitActions: [HabitAction] = []

        // Regex pattern to match [HABIT_COMPLETE: uuid] or [HABIT_SKIP: uuid]
        let pattern = "\\[(HABIT_COMPLETE|HABIT_SKIP):\\s*([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\\]"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return (text, [])
        }

        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        // Process matches in reverse order to avoid index shifting during removal
        for match in matches.reversed() {
            if match.numberOfRanges == 3 {
                let actionRange = match.range(at: 1)
                let uuidRange = match.range(at: 2)

                let action = nsString.substring(with: actionRange)
                let uuidString = nsString.substring(with: uuidRange)

                if let uuid = UUID(uuidString: uuidString) {
                    let habitAction = HabitAction(
                        habitId: uuid,
                        action: action == "HABIT_COMPLETE" ? .complete : .skip
                    )
                    habitActions.append(habitAction)

                    // Remove the marker from the text
                    let fullRange = match.range
                    cleanedText = (cleanedText as NSString).replacingCharacters(in: fullRange, with: "")
                }
            }
        }

        // Clean up any extra whitespace left after removing markers
        cleanedText = cleanedText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")

        return (cleanedText, habitActions)
    }
}

// MARK: - Habit Action

struct HabitAction {
    let habitId: UUID
    let action: Action

    enum Action {
        case complete
        case skip
    }
}

// MARK: - Error Types

enum AIServiceError: Error, LocalizedError {
    case missingAPIKey
    case invalidAPIKey(String)
    case invalidURL
    case invalidRequest
    case noData
    case networkError(String)
    case unauthorized
    case timeout
    case serverError(Int)
    case rateLimitExceeded
    case modelNotFound

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key missing. Open Settings → API Settings to add your OpenAI API key."
        case .invalidAPIKey(let message):
            return "Invalid API key: \(message)"
        case .invalidURL:
            return "Invalid API URL. Check Settings → API Settings and ensure the URL is correct (e.g., https://api.openai.com/v1)"
        case .invalidRequest:
            return "Failed to create API request. Please try again."
        case .noData:
            return "No response from server. Check your internet connection and try again."
        case .networkError(let message):
            return "Network error: \(message). Check your internet connection."
        case .unauthorized:
            return "Invalid API key. Open Settings → API Settings and verify your API key is correct."
        case .timeout:
            return "Request timed out. The server took too long to respond. Please try again."
        case .serverError(let code):
            return "Server error (\(code)). The AI service is experiencing issues. Please try again later."
        case .rateLimitExceeded:
            return "Rate limit exceeded. You've made too many requests. Please wait a moment and try again."
        case .modelNotFound:
            return "Model not found. The specified model may not exist or you don't have access. Check Settings → API Settings."
        }
    }
}

// MARK: - API Key Validation

extension AIService {
    /// Validates API key format for different providers
    /// - Parameters:
    ///   - key: The API key to validate
    ///   - apiURL: The API URL to determine provider
    /// - Throws: AIServiceError.invalidAPIKey if validation fails
    private func validateAPIKey(_ key: String, apiURL: String) throws {
        // Remove whitespace
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)

        // Detect provider from URL
        let urlLower = apiURL.lowercased()

        // Allow blank API keys for localhost/local servers (e.g., LM Studio, Ollama)
        if urlLower.contains("localhost") || urlLower.contains("127.0.0.1") || urlLower.contains("0.0.0.0") {
            LoggerService.ai.info("ℹ️ Local server detected - skipping API key validation")
            return
        }

        guard !trimmedKey.isEmpty else {
            throw AIServiceError.invalidAPIKey("API key is empty")
        }

        if urlLower.contains("openai.com") {
            // OpenAI API keys start with "sk-" (or "sk-proj-" for project keys)
            guard (trimmedKey.hasPrefix("sk-") || trimmedKey.hasPrefix("sk-proj-")) && trimmedKey.count > 20 else {
                throw AIServiceError.invalidAPIKey("OpenAI API key must start with 'sk-' and be longer than 20 characters")
            }
        } else if urlLower.contains("anthropic.com") {
            // Anthropic API keys start with "sk-ant-"
            guard trimmedKey.hasPrefix("sk-ant-") && trimmedKey.count > 20 else {
                throw AIServiceError.invalidAPIKey("Anthropic API key must start with 'sk-ant-' and be longer than 20 characters")
            }
        } else if urlLower.contains("googleapis.com") || urlLower.contains("generativelanguage.googleapis.com") {
            // Google/Gemini API keys
            guard trimmedKey.count > 20 else {
                throw AIServiceError.invalidAPIKey("Google/Gemini API key must be longer than 20 characters")
            }
        } else if urlLower.contains("azure.com") {
            // Azure OpenAI keys
            guard trimmedKey.count > 10 else {
                throw AIServiceError.invalidAPIKey("Azure API key must be longer than 10 characters")
            }
        } else {
            // Generic validation for other providers (strengthened to match other providers)
            guard trimmedKey.count > 20 else {
                throw AIServiceError.invalidAPIKey("API key must be longer than 20 characters")
            }
        }

        LoggerService.ai.info("✅ API key validation passed for provider: \(urlLower.contains("openai") ? "OpenAI" : urlLower.contains("anthropic") ? "Anthropic" : "Generic")")
    }
}
