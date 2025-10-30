import SwiftUI

struct CharacterLibraryView: View {
    var appDelegate: AppDelegate
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery = ""
    @State private var selectedCategory: String? = nil
    @State private var showingAddConfirmation = false
    @State private var templateToAdd: CharacterTemplate? = nil

    private let templateService = CharacterTemplateService.shared
    private let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 20)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Character Library")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Search and Filters
            VStack(spacing: 12) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search templates...", text: $searchQuery)
                        .textFieldStyle(.plain)
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)

                // Category filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryChip(
                            title: "All",
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )

                        ForEach(templateService.getCategories(), id: \.self) { category in
                            CategoryChip(
                                title: category,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                }
            }
            .padding()

            Divider()

            // Template Grid
            ScrollView {
                if filteredTemplates.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No templates found")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        if !searchQuery.isEmpty {
                            Text("Try a different search term")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(filteredTemplates) { template in
                            TemplateCard(template: template) {
                                addCharacter(from: template)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 900, height: 700)
        .alert("Character Added", isPresented: $showingAddConfirmation) {
            Button("OK") { }
        } message: {
            if let template = templateToAdd {
                Text("\(template.name) has been added to your characters!")
            }
        }
    }

    private var filteredTemplates: [CharacterTemplate] {
        var templates = templateService.getAllTemplates()

        // Filter by category
        if let category = selectedCategory {
            templates = templates.filter { $0.category == category }
        }

        // Filter by search query
        if !searchQuery.isEmpty {
            templates = templateService.searchTemplates(query: searchQuery)
            if let category = selectedCategory {
                templates = templates.filter { $0.category == category }
            }
        }

        return templates
    }

    private func addCharacter(from template: CharacterTemplate) {
        // Use smart positioning to place near existing characters
        let position = appDelegate.calculateSmartPosition()

        // Create character from template with calculated position
        var newCharacter = templateService.createCharacter(from: template)
        newCharacter.position = position

        // Add to app state
        appDelegate.appState.addCharacter(newCharacter)

        // Create widget
        appDelegate.createCharacterWidget(for: newCharacter)

        // Schedule all activity notifications for the new character
        ActivityService.shared.scheduleActivities(for: newCharacter)

        templateToAdd = template
        showingAddConfirmation = true

        LoggerService.app.debug("✅ Added character '\(newCharacter.name)' from template '\(template.id)'")
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: CharacterTemplate
    let onAdd: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(avatarGradient(for: template.avatar))
                        .frame(width: 50, height: 50)

                    Text(avatarEmoji(for: template.avatar))
                        .font(.system(size: 24))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text(template.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(4)
                }

                Spacer()
            }

            // Description
            Text(template.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(isExpanded ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)

            // Details toggle
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text(isExpanded ? "Show Less" : "Show Details")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
            .buttonStyle(.plain)

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    // Activities
                    if !template.activities.isEmpty {
                        let trackedCount = template.activities.filter { $0.isTrackingEnabled }.count
                        let reminderCount = template.activities.filter { $0.scheduledTime != nil }.count

                        HStack(spacing: 12) {
                            if trackedCount > 0 {
                                Label("\(trackedCount) Tracked", systemImage: "chart.line.uptrend.xyaxis")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            if reminderCount > 0 {
                                Label("\(reminderCount) Reminders", systemImage: "bell")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(template.activities.indices, id: \.self) { index in
                                let activity = template.activities[index]
                                HStack(spacing: 4) {
                                    Text("•")
                                        .foregroundColor(.secondary)
                                    Text(activity.name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if activity.isTrackingEnabled {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                    if activity.scheduledTime != nil {
                                        Image(systemName: "bell.fill")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                        .padding(.leading, 8)
                    }
                }
            }

            Divider()

            // Add button
            Button(action: onAdd) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Character")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private func avatarGradient(for asset: String) -> LinearGradient {
        switch asset {
        case "person":
            return LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "professional":
            return LinearGradient(colors: [.gray, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "scientist":
            return LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "artist":
            return LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func avatarEmoji(for asset: String) -> String {
        switch asset {
        case "person": return "👤"
        case "professional": return "💼"
        case "scientist": return "👨‍🔬"
        case "artist": return "🎨"
        default: return "👤"
        }
    }
}

// Preview removed - requires AppDelegate
