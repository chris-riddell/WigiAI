//
//  ChatHeaderView.swift
//  WigiAI
//
//  Chat window header with character info and action buttons
//

import SwiftUI

struct ChatHeaderView: View {
    let character: Character
    let characterId: UUID
    let appDelegate: AppDelegate
    let messageCount: Int
    let isTTSEnabled: Bool
    let voiceEnabled: Bool
    @Binding var showingHabitProgress: Bool
    @Binding var showingClearConfirmation: Bool
    let onToggleTTS: () -> Void
    let onOpenSettings: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Text(avatarEmoji(for: character.avatarAsset))
                        .font(.system(size: 20))
                )
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(character.name)
                    .font(.headline)
                Text("\(messageCount) messages")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Habit progress button (only show if character has tracked activities)
            if !character.activities.filter({ $0.isTrackingEnabled && $0.isEnabled }).isEmpty {
                Button(action: {
                    showingHabitProgress.toggle()
                }) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 14))
                        .foregroundColor(showingHabitProgress ? .blue : .secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(HoverButtonStyle())
                .help("View habit progress")
                .popover(isPresented: $showingHabitProgress, arrowEdge: .bottom) {
                    if let character = appDelegate.appState.character(withId: characterId) {
                        HabitProgressView(
                            character: Binding(
                                get: { appDelegate.appState.character(withId: characterId) ?? character },
                                set: { newValue in
                                    appDelegate.appState.updateCharacter(newValue)
                                }
                            ),
                            onClose: {
                                showingHabitProgress = false
                            }
                        )
                    }
                }
            }

            Button(action: {
                showingClearConfirmation = true
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(HoverButtonStyle())
            .help("Clear conversation history")
            .disabled(messageCount == 0)

            // TTS Mute/Unmute button (show if voice is enabled, even if currently muted)
            if voiceEnabled {
                Button(action: onToggleTTS) {
                    Image(systemName: isTTSEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 14))
                        .foregroundColor(isTTSEnabled ? .blue : .secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(HoverButtonStyle())
                .help(isTTSEnabled ? "Mute voice responses" : "Unmute voice responses")
            }

            // Settings gear button
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(HoverButtonStyle())
            .help("Character settings")

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(HoverButtonStyle())
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private func avatarEmoji(for avatarAsset: String) -> String {
        switch avatarAsset {
        case "person": return "🧑"
        case "professional": return "👨‍💼"
        case "scientist": return "🧑‍🔬"
        case "artist": return "🧑‍🎨"
        default: return "🧑"
        }
    }
}
