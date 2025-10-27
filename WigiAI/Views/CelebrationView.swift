//
//  CelebrationView.swift
//  WigiAI
//
//  Celebration animations for habit completions
//

import SwiftUI

struct CelebrationView: View {
    let habitName: String
    let streak: Int
    @Binding var isPresented: Bool

    @State private var confettiPieces: [ConfettiPiece] = []
    @State private var opacity: Double = 1.0

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Celebration content
            VStack(spacing: 20) {
                // Success icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.green, .green.opacity(0.7)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: .green.opacity(0.5), radius: 20, x: 0, y: 10)

                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(opacity) // Bounce effect

                // Habit name
                Text(habitName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                // Completion message
                Text("Completed!")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))

                // Streak info
                if streak > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                        Text("\(streak) day streak!")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.3))
                    .cornerRadius(12)
                }

                // Milestone message
                if let milestone = getMilestoneMessage(for: streak) {
                    Text(milestone)
                        .font(.subheadline)
                        .foregroundColor(.yellow)
                        .fontWeight(.medium)
                }
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            .scaleEffect(opacity)

            // Confetti overlay
            ForEach(confettiPieces) { piece in
                ConfettiPieceView(piece: piece)
            }
        }
        .opacity(opacity)
        .onAppear {
            startCelebration()
        }
    }

    private func startCelebration() {
        // Create confetti pieces
        for _ in 0..<50 {
            confettiPieces.append(ConfettiPiece())
        }

        // Bounce animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            opacity = 1.0
        }

        // Auto-dismiss after 2.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 0.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }

    private func getMilestoneMessage(for streak: Int) -> String? {
        switch streak {
        case 1:
            return "Great start! 🌟"
        case 3:
            return "Three in a row! 🎯"
        case 7:
            return "One week strong! 💪"
        case 14:
            return "Two weeks - amazing! 🔥"
        case 30:
            return "One month milestone! 🏆"
        case 100:
            return "Century club! Incredible! 🌈"
        default:
            if streak % 50 == 0 {
                return "\(streak) days - unstoppable! 🚀"
            }
            return nil
        }
    }
}

// MARK: - Confetti Piece

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    let startX: CGFloat
    let startY: CGFloat
    let rotation: Double
    let velocity: CGFloat

    init() {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
        self.color = colors.randomElement()!
        self.size = CGFloat.random(in: 6...12)
        self.startX = CGFloat.random(in: 0...600)
        self.startY = CGFloat.random(in: -100...0)
        self.rotation = Double.random(in: 0...360)
        self.velocity = CGFloat.random(in: 2...5)
    }
}

struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    @State private var yOffset: CGFloat = 0
    @State private var xOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1.0

    var body: some View {
        Circle()
            .fill(piece.color)
            .frame(width: piece.size, height: piece.size)
            .offset(x: piece.startX + xOffset, y: piece.startY + yOffset)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .onAppear {
                withAnimation(.linear(duration: 3.0)) {
                    yOffset = 800
                    xOffset = CGFloat.random(in: -50...50)
                    rotation = piece.rotation + 360
                }

                withAnimation(.easeOut(duration: 3.0)) {
                    opacity = 0.0
                }
            }
    }
}

// MARK: - Preview

#Preview {
    CelebrationView(
        habitName: "Exercise",
        streak: 7,
        isPresented: .constant(true)
    )
    .frame(width: 500, height: 600)
}
