//
//  CharacterWidget.swift
//  WigiAI
//
//  AI Companion Desktop Widget
//

import SwiftUI

@MainActor
struct CharacterWidget: View {
    let characterId: UUID
    let appDelegate: AppDelegate
    @State private var moveObserver: NSObjectProtocol?
    @State private var isHovering = false
    @State private var badgePulse = false
    @State private var breathingPhase: CGFloat = 0

    // Always get fresh character from appState
    private var character: Character {
        appDelegate.appState.character(withId: characterId) ??
            Character(name: "Unknown", masterPrompt: "", position: .zero)
    }

    var body: some View {
        ZStack(alignment: .center) {
            // Simple Avatar with gentle breathing
            avatarView(for: character.avatarAsset)
                .frame(width: 100, height: 100)
                .scaleEffect(1.0 + Foundation.sin(breathingPhase) * 0.015) // Subtle breathing
                .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: breathingPhase)
                .shadow(
                    color: .black.opacity(isHovering ? 0.4 : 0.25),
                    radius: isHovering ? 10 : 6,
                    x: 0,
                    y: isHovering ? 4 : 2
                )
                .scaleEffect(isHovering ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)

            // Name label on hover - simplified for debugging
            if isHovering {
                Text(character.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(6)
                    .offset(y: 60)
                    .zIndex(10)
                    .transition(.opacity)
            }

            // Notification badge for reminders/habits
            if character.hasNotification {
                Circle()
                    .fill(Color.red)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text("!")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .offset(x: 30, y: -30)
                    .shadow(color: .red.opacity(0.5), radius: 4, x: 0, y: 2)
                    .scaleEffect(badgePulse ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true),
                        value: badgePulse
                    )
                    .onAppear {
                        badgePulse = true
                    }
            }
        }
        .contentShape(Rectangle())
        .frame(width: 140, height: 170)  // Extra space for hover label below avatar
        .accessibilityLabel("\(character.name) character widget")
        .accessibilityHint(character.hasNotification ? "Has pending notification. Click to open chat." : "Click to open chat with \(character.name)")
        .accessibilityAddTraits(.isButton)
        .onHover { hovering in
            print("🔍 Hover state changed: \(hovering) for \(character.name)")
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            // Simple tap gesture for opening chat - much more reliable than drag detection
            LoggerService.ui.info("🖱️ Click detected - opening chat for \(character.name)")
            appDelegate.openChatWindow(for: character)
        }
        .onAppear {
            // Start breathing animation
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: true)) {
                breathingPhase = .pi * 2
            }

            // Remove any existing observer first
            if let observer = moveObserver {
                NotificationCenter.default.removeObserver(observer)
            }

            // Save position when window is moved
            let appDelegate = self.appDelegate
            let characterId = self.characterId
            moveObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didMoveNotification,
                object: nil,
                queue: .main
            ) { notification in
                // Already on main queue, dispatch to main actor for UI updates
                Task { @MainActor in
                    if let window = notification.object as? CharacterPanel,
                       window.characterId == characterId {
                        let windowOrigin = window.frame.origin
                        LoggerService.ui.info("📍 Widget moved to: \(NSStringFromPoint(windowOrigin))")

                        // Update position via AppState
                        appDelegate.appState.updateCharacterPosition(id: characterId, position: windowOrigin)
                        LoggerService.ui.info("💾 Position saved")
                    }
                }
            }
        }
        .onDisappear {
            // Clean up observer
            if let observer = moveObserver {
                NotificationCenter.default.removeObserver(observer)
                moveObserver = nil
            }
        }
    }

    // MARK: - Helper Methods

    /// Returns the gradient colors for a character's avatar type
    func gradientColors(for avatarAsset: String) -> [Color] {
        switch avatarAsset {
        case "person":
            return [.blue.opacity(0.8), .purple.opacity(0.8)]
        case "professional":
            return [.gray.opacity(0.8), .blue.opacity(0.8)]
        case "scientist":
            return [.green.opacity(0.8), .teal.opacity(0.8)]
        case "artist":
            return [.purple.opacity(0.8), .pink.opacity(0.8)]
        default:
            return [.blue.opacity(0.8), .purple.opacity(0.8)]
        }
    }

    // MARK: - Avatar Views

    @ViewBuilder
    func avatarView(for avatarAsset: String) -> some View {
        switch avatarAsset {
        case "person":
            ZStack {
                // Glassmorphism background
                Circle()
                    .fill(.ultraThinMaterial)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue.opacity(0.8), .purple.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    )

                Text("🧑")
                    .font(.system(size: 40))
            }

        case "professional":
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.gray.opacity(0.8), .blue.opacity(0.8)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    )

                Text("👨‍💼")
                    .font(.system(size: 40))
            }

        case "scientist":
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.green.opacity(0.8), .teal.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    )

                Text("🧑‍🔬")
                    .font(.system(size: 40))
            }

        case "artist":
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.purple.opacity(0.8), .pink.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    )

                Text("🧑‍🎨")
                    .font(.system(size: 40))
            }

        default:
            // Default: show person emoji with glassmorphism
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue.opacity(0.8), .purple.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    )

                Text("🧑")
                    .font(.system(size: 40))
            }
        }
    }
}
