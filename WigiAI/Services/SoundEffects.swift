//
//  SoundEffects.swift
//  WigiAI
//
//  Subtle sound effects for user interactions
//

import AppKit

/// Service for playing system sound effects for UI feedback
///
/// Uses macOS built-in sounds for subtle auditory feedback during user interactions.
/// All sounds are non-blocking and play asynchronously.
///
/// **Sound Choices:**
/// - Message sent: "Pop" (quick, affirmative)
/// - Message received: "Bottle" (gentle, distinct)
/// - Success: "Glass" (pleasant, achievement)
/// - Celebration: "Hero" (triumphant, milestone)
/// - Streak milestone: "Funk" (special, exciting)
/// - Error: System beep (standard macOS error sound)
class SoundEffects {
    /// Shared singleton instance
    static let shared = SoundEffects()

    private init() {}

    /// Plays sound when user sends a message
    func playMessageSent() {
        NSSound(named: "Pop")?.play()
    }

    /// Plays sound when AI response is received
    func playMessageReceived() {
        NSSound(named: "Bottle")?.play()
    }

    /// Plays sound when an error occurs
    func playError() {
        NSSound.beep()
    }

    /// Plays sound for successful operation
    func playSuccess() {
        NSSound(named: "Glass")?.play()
    }

    /// Plays celebration sound for habit completion
    ///
    /// Used when user completes a habit or achieves a goal
    func playCelebration() {
        NSSound(named: "Hero")?.play()
    }

    /// Plays special sound for streak milestones
    ///
    /// Used for significant achievements (e.g., 7-day streak, 30-day streak)
    func playStreakMilestone() {
        NSSound(named: "Funk")?.play()
    }
}
