//
//  HabitQuickActions.swift
//  WigiAI
//
//  Quick action buttons for marking habits complete/skipped
//

import SwiftUI
import OSLog

struct HabitQuickActions: View {
    let character: Character
    let onHabitAction: (Habit, HabitAction.Action) -> Void

    var pendingHabits: [Habit] {
        let today = Date()
        return character.habits.filter { habit in
            habit.isEnabled &&
            habit.isDueOn(date: today) &&
            !habit.isCompletedOn(date: today) &&
            !habit.isSkippedOn(date: today)
        }
    }

    var body: some View {
        if !pendingHabits.isEmpty {
            VStack(spacing: 0) {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("Pending Habits Today")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }

                    ForEach(pendingHabits) { habit in
                        HabitQuickActionRow(
                            habit: habit,
                            onComplete: {
                                onHabitAction(habit, .complete)
                            },
                            onSkip: {
                                onHabitAction(habit, .skip)
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
        }
    }
}

struct HabitQuickActionRow: View {
    let habit: Habit
    let onComplete: () -> Void
    let onSkip: () -> Void

    @State private var isCompleting = false
    @State private var isSkipping = false
    @State private var isHidden = false

    var body: some View {
        if !isHidden {
            HStack(spacing: 8) {
                // Habit info
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(habit.targetDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Action buttons
                HStack(spacing: 6) {
                    Button(action: {
                        withAnimation {
                            isCompleting = true
                        }
                        onComplete()
                        // Hide after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation {
                                isHidden = true
                            }
                        }
                    }) {
                    HStack(spacing: 4) {
                        Image(systemName: isCompleting ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.caption)
                        Text("Done")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isCompleting ? Color.green : Color.green.opacity(0.1))
                    .foregroundColor(isCompleting ? .white : .green)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(isCompleting || isSkipping)

                Button(action: {
                    withAnimation {
                        isSkipping = true
                    }
                    onSkip()
                    // Hide after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            isHidden = true
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isSkipping ? "xmark.circle.fill" : "xmark.circle")
                            .font(.caption)
                        Text("Skip")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isSkipping ? Color.orange : Color.orange.opacity(0.1))
                    .foregroundColor(isSkipping ? .white : .orange)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(isCompleting || isSkipping)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        HabitQuickActions(
            character: Character(
                name: "Test",
                masterPrompt: "Test",
                habits: [
                    Habit(
                        name: "Exercise",
                        targetDescription: "30 minutes of cardio",
                        frequency: .daily,
                        isEnabled: true
                    ),
                    Habit(
                        name: "Read",
                        targetDescription: "20 pages",
                        frequency: .daily,
                        isEnabled: true
                    )
                ]
            ),
            onHabitAction: { habit, action in
                LoggerService.habits.debug("Preview action: \(String(describing: action)) for habit: \(habit.name)")
            }
        )
        .frame(width: 400)
    }
}
