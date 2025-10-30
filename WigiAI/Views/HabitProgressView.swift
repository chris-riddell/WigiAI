//
//  HabitProgressView.swift
//  WigiAI
//
//  Habit progress visualization (7-day calendar view)
//

import SwiftUI

struct HabitProgressView: View {
    @Binding var character: Character
    let onClose: () -> Void
    @State private var refreshTrigger = false

    var activeActivities: [Activity] {
        character.activities.filter { $0.isEnabled && $0.isTrackingEnabled }
    }

    func refreshView() {
        refreshTrigger.toggle()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Habit Progress")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Content
            if activeActivities.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("No Tracked Activities")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    Text("Add tracked activities in Character Settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(character.activities.indices, id: \.self) { index in
                            if character.activities[index].isEnabled && character.activities[index].isTrackingEnabled {
                                HabitProgressRow(habit: $character.activities[index], onRefresh: refreshView)
                                    .id("\(character.activities[index].id)-\(refreshTrigger)")
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(width: 400, height: 450)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Activity Progress Row

struct HabitProgressRow: View {
    @Binding var habit: Activity
    let onRefresh: () -> Void
    @State private var weekOffset: Int = 0

    // Get 7 days based on the current week offset
    // Shows the last 7 days ending at (today - weekOffset*7)
    var weekDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let endOfPeriod = calendar.date(byAdding: .day, value: weekOffset * 7, to: today)!
        return (0..<7).reversed().map { offset in
            calendar.date(byAdding: .day, value: -offset, to: endOfPeriod)!
        }
    }

    var canGoToNextWeek: Bool {
        // Can't go to future weeks
        weekOffset >= 0
    }

    var weekLabel: String {
        let calendar = Calendar.current
        let today = Date()
        let endOfPeriod = calendar.date(byAdding: .day, value: weekOffset * 7, to: today)!
        let startOfPeriod = calendar.date(byAdding: .day, value: -6, to: endOfPeriod)!

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let startStr = formatter.string(from: startOfPeriod)
        let endStr = formatter.string(from: endOfPeriod)

        if weekOffset == 0 {
            return "Last 7 Days"
        } else {
            return "\(startStr) - \(endStr)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Habit name and streak
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.headline)

                    Text(habit.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Streak badge
                if habit.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("\(habit.currentStreak)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(8)
                }
            }

            // Week navigation and label
            HStack {
                Button(action: {
                    weekOffset -= 1
                }) {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                }
                .buttonStyle(.borderless)

                Spacer()

                Text(weekLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    weekOffset += 1
                }) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(canGoToNextWeek)
            }
            .padding(.horizontal, 4)

            // 7-day calendar view
            HStack(spacing: 8) {
                ForEach(weekDays, id: \.self) { date in
                    DaySquare(habit: $habit, date: date, onRefresh: onRefresh)
                }
            }

            // Completion stats
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("\(habit.totalCompletions) total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                let rate = Int(habit.completionRate * 100)
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("\(rate)% (30 days)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Day Square

struct DaySquare: View {
    @Binding var habit: Activity
    let date: Date
    let onRefresh: () -> Void
    @State private var updateTrigger = false

    var isDue: Bool {
        habit.isDueOn(date: date)
    }

    var isCompleted: Bool {
        habit.isCompletedOn(date: date)
    }

    var isSkipped: Bool {
        habit.isSkippedOn(date: date)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var isMissed: Bool {
        // Missed = was due, is in the past, and not completed/skipped
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return isDue && date < today && !isCompleted && !isSkipped
    }

    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1)) // First letter (M, T, W, etc.)
    }

    var backgroundColor: Color {
        if isCompleted {
            return .green.opacity(0.8)
        } else if isSkipped {
            return .red.opacity(0.6)
        } else if isMissed {
            return .yellow.opacity(0.7)
        } else if isDue {
            return .gray.opacity(0.2)
        } else {
            return .clear
        }
    }

    var borderColor: Color {
        if isToday {
            return .blue
        } else if isDue || isMissed {
            return .gray.opacity(0.3)
        } else {
            return .gray.opacity(0.1)
        }
    }

    var statusIcon: String? {
        if isCompleted {
            return "checkmark"
        } else if isSkipped {
            return "xmark"
        } else if isMissed {
            return "exclamationmark"
        } else {
            return nil
        }
    }

    func toggleStatus() {
        let calendar = Calendar.current
        let dateKey = calendar.startOfDay(for: date)

        LoggerService.app.debug("🔄 BEFORE toggle - completions: \(habit.completionDates.count), skips: \(habit.skipDates.count)")

        // Create a mutable copy
        var updatedHabit = habit

        if isCompleted {
            LoggerService.app.debug("   State: Completed -> Skipped")
            // Completed -> Skipped
            // Remove from completion dates, add to skip dates
            updatedHabit.completionDates.removeAll { calendar.isDate($0, inSameDayAs: dateKey) }
            if !updatedHabit.skipDates.contains(where: { calendar.isDate($0, inSameDayAs: dateKey) }) {
                updatedHabit.skipDates.append(dateKey)
            }
        } else if isSkipped {
            LoggerService.app.debug("   State: Skipped -> Clear")
            // Skipped -> Clear
            // Remove from skip dates
            updatedHabit.skipDates.removeAll { calendar.isDate($0, inSameDayAs: dateKey) }
        } else {
            LoggerService.app.debug("   State: Clear/Missed -> Completed")
            // Clear/Missed -> Completed
            // Add to completion dates, remove from skip dates if present
            updatedHabit.skipDates.removeAll { calendar.isDate($0, inSameDayAs: dateKey) }
            if !updatedHabit.completionDates.contains(where: { calendar.isDate($0, inSameDayAs: dateKey) }) {
                updatedHabit.completionDates.append(dateKey)
            }
        }

        // Trigger SwiftUI update by reassigning the entire habit
        habit = updatedHabit

        // Force view refresh
        updateTrigger.toggle()
        onRefresh()

        LoggerService.app.debug("🔄 AFTER toggle - completions: \(habit.completionDates.count), skips: \(habit.skipDates.count)")
        LoggerService.app.debug("   Visual update triggered: \(updateTrigger)")
    }

    var body: some View {
        VStack(spacing: 4) {
            // Day square
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: isToday ? 2 : 1)
                    )

                if let icon = statusIcon {
                    Image(systemName: icon)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                } else if !isDue {
                    // Not due - show subtle dot
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 4, height: 4)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                LoggerService.app.debug("👆 Tapped on \(dayLabel) - isDue: \(isDue), isMissed: \(isMissed), isCompleted: \(isCompleted), isSkipped: \(isSkipped)")
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    toggleStatus()
                }
            }

            // Day label
            Text(dayLabel)
                .font(.caption2)
                .foregroundColor(isToday ? .blue : .secondary)
                .fontWeight(isToday ? .semibold : .regular)
        }
        .id("\(date.timeIntervalSince1970)-\(updateTrigger)")
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var character = Character(
            name: "Test",
            masterPrompt: "Test",
            activities: [
                Activity(
                    name: "Exercise",
                    description: "30 minutes of cardio",
                    frequency: .daily,
                    isTrackingEnabled: true,
                    completionDates: [
                        Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                        Calendar.current.date(byAdding: .day, value: -2, to: Date())!
                    ],
                    isEnabled: true
                ),
                Activity(
                    name: "Read",
                    description: "20 pages",
                    frequency: .daily,
                    isTrackingEnabled: true,
                    isEnabled: true
                )
            ]
        )

        var body: some View {
            HabitProgressView(
                character: $character,
                onClose: {}
            )
        }
    }

    return PreviewWrapper()
}
