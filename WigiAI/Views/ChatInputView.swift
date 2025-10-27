//
//  ChatInputView.swift
//  WigiAI
//
//  Chat input area with voice and text input
//

import SwiftUI
import Speech

struct ChatInputView: View {
    @Binding var userInput: String
    @Binding var errorMessage: String?
    let suggestedMessages: [String]
    let isStreaming: Bool
    let characterName: String

    // Voice settings
    let voiceEnabled: Bool
    let sttEnabled: Bool
    @Binding var isPushToTalkActive: Bool
    @ObservedObject var voiceService: VoiceService

    // Callbacks
    let onSendMessage: () -> Void
    let onStartPushToTalk: () -> Void
    let onStopPushToTalk: () -> Void
    let onSendSuggestion: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Error display
            if let error = errorMessage {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            errorMessage = nil
                        }
                        // Retry the last user message
                        onSendMessage()
                    }) {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.orange)

                    Button("Dismiss") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            errorMessage = nil
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
                .padding(12)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Suggested Messages
            if !suggestedMessages.isEmpty && !isStreaming {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestedMessages, id: \.self) { suggestion in
                            Button(action: {
                                onSendSuggestion(suggestion)
                            }) {
                                Text(suggestion)
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(.thinMaterial)
                                    .foregroundColor(.primary)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(SuggestionButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
                .background(.regularMaterial)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Input area
            HStack(spacing: 12) {
                // Push-to-talk button (experimental feature)
                if voiceEnabled && sttEnabled {
                    Button(action: {}) {
                        ZStack {
                            Circle()
                                .fill(
                                    isPushToTalkActive
                                        ? LinearGradient(
                                            gradient: Gradient(colors: [.red, .orange]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        : LinearGradient(
                                            gradient: Gradient(colors: [.gray.opacity(0.3), .gray.opacity(0.5)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                )
                                .frame(width: 40, height: 40)
                                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                            Image(systemName: isPushToTalkActive ? "mic.fill" : "mic")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            // Pulsing animation when listening
                            if isPushToTalkActive {
                                Circle()
                                    .stroke(Color.red.opacity(0.5), lineWidth: 2)
                                    .frame(width: 50, height: 50)
                                    .scaleEffect(voiceService.isListening ? 1.2 : 1.0)
                                    .opacity(voiceService.isListening ? 0 : 1)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false), value: voiceService.isListening)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help(isPushToTalkActive ? "Release to stop recording" : "Hold to talk")
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !isPushToTalkActive {
                                    onStartPushToTalk()
                                }
                            }
                            .onEnded { _ in
                                if isPushToTalkActive {
                                    onStopPushToTalk()
                                }
                            }
                    )
                }

                ZStack(alignment: .topLeading) {
                    // Placeholder text
                    if userInput.isEmpty {
                        Text(voiceEnabled && sttEnabled ? "Press Space to talk or type a message..." : "Type a message...")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                    }

                    TextEditor(text: $userInput)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .frame(minHeight: 40, maxHeight: 120)
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .accessibilityLabel("Message input")
                        .accessibilityHint("Type your message to \(characterName)")
                }
                .background(.regularMaterial)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )

                Button(action: onSendMessage) {
                    Image(systemName: isStreaming ? "stop.circle.fill" : "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Group {
                                if isStreaming {
                                    Color.orange
                                } else if userInput.isEmpty {
                                    Color.gray.opacity(0.5)
                                } else {
                                    LinearGradient(
                                        gradient: Gradient(colors: [.blue, .purple]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                }
                            }
                        )
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        .scaleEffect(isStreaming ? 1.0 : (userInput.isEmpty ? 0.9 : 1.0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: userInput.isEmpty)
                }
                .buttonStyle(.plain)
                .disabled(userInput.isEmpty && !isStreaming)
                .accessibilityLabel(isStreaming ? "Stop response" : "Send message")
                .accessibilityHint(isStreaming ? "Stop the AI response" : "Send your message to \(characterName)")
            }
            .padding(16)
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Button Styles

struct HoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SuggestionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
