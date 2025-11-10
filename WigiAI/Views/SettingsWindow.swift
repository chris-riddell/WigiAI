//
//  SettingsWindow.swift
//  WigiAI
//
//  AI Companion Desktop Widget
//

import SwiftUI
import ServiceManagement

// App Settings Window (API + General Settings only)
struct AppSettingsWindow: View {
    var appDelegate: AppDelegate
    @ObservedObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Manual tab bar
            Picker("", selection: $selectedTab) {
                Label("API Settings", systemImage: "network")
                    .tag(0)
                Label("General", systemImage: "gearshape.fill")
                    .tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case 0:
                    APISettingsTab(appDelegate: appDelegate, appState: appState)
                case 1:
                    GeneralSettingsTab(appDelegate: appDelegate, appState: appState)
                default:
                    APISettingsTab(appDelegate: appDelegate, appState: appState)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 600, idealWidth: 600, minHeight: 500, idealHeight: 500)
    }
}

// Characters Window (just character management)
struct CharactersWindow: View {
    var appDelegate: AppDelegate
    @ObservedObject var appState: AppState
    let selectedCharacterID: UUID?

    var body: some View {
        CharactersTab(appDelegate: appDelegate, appState: appState, initialSelectedCharacterID: selectedCharacterID)
            .frame(minWidth: 700, idealWidth: 700, minHeight: 600, idealHeight: 600)
    }
}

// Legacy SettingsWindow (kept for compatibility, but not used)
struct SettingsWindow: View {
    var appDelegate: AppDelegate
    @ObservedObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            CharactersTab(appDelegate: appDelegate, appState: appState, initialSelectedCharacterID: nil)
                .tabItem {
                    Label("Characters", systemImage: "person.2.fill")
                }
                .tag(0)

            APISettingsTab(appDelegate: appDelegate, appState: appState)
                .tabItem {
                    Label("API", systemImage: "network")
                }
                .tag(1)

            GeneralSettingsTab(appDelegate: appDelegate, appState: appState)
                .tabItem {
                    Label("General", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tabViewStyle(.automatic)
        .frame(minWidth: 600, idealWidth: 600, minHeight: 500, idealHeight: 500)
    }
}

// MARK: - Characters Tab

struct CharactersTab: View {
    var appDelegate: AppDelegate
    @ObservedObject var appState: AppState
    let initialSelectedCharacterID: UUID?
    @State private var selectedCharacterID: UUID?
    @State private var showingNamePrompt = false
    @State private var newCharacterName = ""
    @State private var showingLibrary = false
    @State private var showingDeleteConfirmation = false

    init(appDelegate: AppDelegate, appState: AppState, initialSelectedCharacterID: UUID? = nil) {
        self.appDelegate = appDelegate
        self._appState = ObservedObject(wrappedValue: appState)
        self.initialSelectedCharacterID = initialSelectedCharacterID
        _selectedCharacterID = State(initialValue: initialSelectedCharacterID)
    }

    var selectedCharacter: Character? {
        guard let id = selectedCharacterID else { return nil }
        return appDelegate.appState.character(withId: id)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Character List
            VStack(alignment: .leading, spacing: 0) {
                List(selection: $selectedCharacterID) {
                    ForEach(appDelegate.appState.characters) { character in
                        HStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.blue, .purple]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Text(avatarEmoji(for: character.avatarAsset))
                                        .font(.system(size: 15))
                                )

                            Text(character.name)
                                .font(.body)
                        }
                        .tag(character.id)
                    }
                }
                .listStyle(.sidebar)

                Divider()

                HStack(spacing: 6) {
                    Button(action: {
                        newCharacterName = ""
                        showingNamePrompt = true
                    }) {
                        Image(systemName: "plus")
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .help("Create New Character")

                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        Image(systemName: "minus")
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .disabled(selectedCharacter == nil)
                    .help("Delete Selected Character")

                    Spacer()

                    Button(action: {
                        showingLibrary = true
                    }) {
                        Image(systemName: "books.vertical")
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .help("Browse Character Library")
                }
                .padding(8)
            }
            .frame(minWidth: 200, idealWidth: 200, maxWidth: 200)

            Divider()

            // Character Editor
            if let character = selectedCharacter {
                CharacterEditor(
                    character: Binding(
                        get: { character },
                        set: { updatedCharacter in
                            appDelegate.updateCharacter(updatedCharacter)
                        }
                    ),
                    appDelegate: appDelegate
                )
                .environmentObject(appState)
            } else if appDelegate.appState.characters.isEmpty {
                // Empty state - no characters created
                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 80))
                        .foregroundColor(.blue.opacity(0.6))

                    VStack(spacing: 8) {
                        Text("No Characters Yet")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Create a character from scratch or choose from our library")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: 16) {
                        Button(action: {
                            newCharacterName = ""
                            showingNamePrompt = true
                        }) {
                            Label("Create New", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button(action: {
                            showingLibrary = true
                        }) {
                            Label("Browse Library", systemImage: "books.vertical.fill")
                                .font(.headline)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // Empty state - no character selected
                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "arrow.left.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary.opacity(0.5))

                    VStack(spacing: 8) {
                        Text("Select a character")
                            .font(.title3)
                            .foregroundColor(.secondary)

                        Text("Choose a character from the list to edit")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Text("or")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)

                    HStack(spacing: 16) {
                        Button(action: {
                            newCharacterName = ""
                            showingNamePrompt = true
                        }) {
                            Label("Create New Character", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button(action: {
                            showingLibrary = true
                        }) {
                            Label("Browse Library", systemImage: "books.vertical.fill")
                                .font(.headline)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .alert("New Character", isPresented: $showingNamePrompt) {
            TextField("Character Name", text: $newCharacterName)
            Button("Cancel", role: .cancel) {
                newCharacterName = ""
            }
            Button("Create") {
                createNewCharacter()
            }
            .disabled(newCharacterName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text("Enter a name for your new character")
        }
        .sheet(isPresented: $showingLibrary) {
            CharacterLibraryView(appDelegate: appDelegate, appState: appState)
        }
        .alert("Delete Character", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedCharacter()
            }
        } message: {
            if let character = selectedCharacter {
                Text("Are you sure you want to delete '\(character.name)'? This will remove the character, all chat history, and activities. This action cannot be undone.")
            }
        }
    }

    func createNewCharacter() {
        let name = newCharacterName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        // Use smart positioning to place near existing characters
        let position = appDelegate.calculateSmartPosition()

        let newCharacter = Character(
            name: name,
            masterPrompt: "You are a friendly AI companion who helps with daily check-ins and habit tracking.",
            position: position
        )

        appDelegate.appState.addCharacter(newCharacter)
        appDelegate.createCharacterWidget(for: newCharacter)

        // Select the newly created character
        selectedCharacterID = newCharacter.id

        newCharacterName = ""
    }

    func deleteSelectedCharacter() {
        guard let id = selectedCharacterID else { return }

        appDelegate.removeCharacterWidget(id: id)
        appDelegate.appState.deleteCharacter(id: id)
        selectedCharacterID = nil
    }

    func avatarEmoji(for avatarAsset: String) -> String {
        switch avatarAsset {
        case "person": return "🧑"
        case "professional": return "👨‍💼"
        case "scientist": return "🧑‍🔬"
        case "artist": return "🧑‍🎨"
        default: return "🧑"
        }
    }
}

// MARK: - Character Editor

struct CharacterEditor: View {
    @Binding var character: Character
    @State private var showingActivitySheet = false
    @State private var editingActivity: Activity? = nil
    @State private var activityToDelete: Activity? = nil
    @ObservedObject private var voiceService = VoiceService.shared
    @EnvironmentObject var appState: AppState
    var appDelegate: AppDelegate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Basic Information
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                            Text("Basic Information")
                                .font(.headline)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Character name", text: $character.name)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Avatar Style")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("Avatar Style", selection: $character.avatarAsset) {
                                Text("🧑 Person").tag("person")
                                Text("👨‍💼 Professional").tag("professional")
                                Text("🧑‍🔬 Scientist").tag("scientist")
                                Text("🧑‍🎨 Artist").tag("artist")
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }
                    .padding(16)
                }

                // Master Prompt
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "text.bubble.fill")
                                .foregroundColor(.purple)
                                .font(.title3)
                            Text("Master Prompt")
                                .font(.headline)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            TextEditor(text: $character.masterPrompt)
                                .frame(height: 120)
                                .font(.body)
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            Text("Define the character's personality and purpose")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                }

                // Current Context
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.green)
                                .font(.title3)
                            Text("Current Context")
                                .font(.headline)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            TextEditor(text: $character.persistentContext)
                                .frame(height: 80)
                                .font(.body)
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            Text("AI-maintained summary of key information (auto-updates after each chat)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                }

                // Activities (unified reminders + habits)
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.blue)
                                .font(.title3)
                            Text("Activities")
                                .font(.headline)
                            Spacer()
                            Text("Optional")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            if character.activities.isEmpty {
                                HStack {
                                    Image(systemName: "calendar.badge.clock")
                                        .foregroundColor(.secondary)
                                    Text("No activities configured")
                                        .foregroundColor(.secondary)
                                        .font(.subheadline)
                                }
                                .padding(.vertical, 8)
                            } else {
                                ForEach(character.activities) { activity in
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(activity.name)
                                                    .font(.headline)

                                                // Tracking badge
                                                if activity.isTrackingEnabled {
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                                            .font(.caption2)
                                                            .foregroundColor(.blue)
                                                        Text("Tracked")
                                                            .font(.caption2)
                                                            .fontWeight(.semibold)
                                                    }
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.blue.opacity(0.15))
                                                    .cornerRadius(4)
                                                }

                                                // Streak badge (only for tracked activities)
                                                if activity.isTrackingEnabled && activity.currentStreak > 0 {
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "flame.fill")
                                                            .font(.caption2)
                                                            .foregroundColor(.orange)
                                                        Text("\(activity.currentStreak)")
                                                            .font(.caption)
                                                            .fontWeight(.semibold)
                                                    }
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.orange.opacity(0.15))
                                                    .cornerRadius(4)
                                                }
                                            }

                                            Text(activity.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)

                                            HStack(spacing: 8) {
                                                Text(activity.frequency.displayName)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)

                                                if let scheduledTime = activity.scheduledTime {
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "bell.fill")
                                                            .font(.caption2)
                                                        Text(scheduledTime, style: .time)
                                                            .font(.caption2)
                                                    }
                                                    .foregroundColor(.orange)
                                                }
                                            }
                                        }

                                        Spacer()

                                        Toggle("", isOn: Binding(
                                            get: { activity.isEnabled },
                                            set: { newValue in
                                                if let index = character.activities.firstIndex(where: { $0.id == activity.id }) {
                                                    character.activities[index].isEnabled = newValue
                                                }
                                            }
                                        ))
                                        .labelsHidden()

                                        Button(action: {
                                            activityToDelete = activity
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                                .font(.system(size: 14))
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    .padding(12)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingActivity = activity
                                        showingActivitySheet = true
                                    }
                                }
                            }

                            Button(action: {
                                editingActivity = nil
                                showingActivitySheet = true
                            }) {
                                Label("Add Activity", systemImage: "plus.circle.fill")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(16)
                }

                // Voice Settings (only show if global voice is enabled)
                if appState.settings.voiceSettings.enabled {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "waveform")
                                    .foregroundColor(.cyan)
                                    .font(.title3)
                                Text("Voice Settings")
                                    .font(.headline)
                                Spacer()
                                HStack(spacing: 4) {
                                    Text("EXPERIMENTAL")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.orange)
                                    Text("• Optional")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(4)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 12) {
                                Toggle("Use custom voice for this character", isOn: Binding(
                                    get: { character.customVoiceIdentifier != nil },
                                    set: { enabled in
                                        withAnimation {
                                            if enabled {
                                                // Initialize with global defaults
                                                character.customVoiceIdentifier = appState.settings.voiceSettings.voiceIdentifier
                                                character.customSpeechRate = appState.settings.voiceSettings.speechRate
                                            } else {
                                                character.customVoiceIdentifier = nil
                                                character.customSpeechRate = nil
                                            }
                                        }
                                    }
                                ))

                                if character.customVoiceIdentifier != nil {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Divider()

                                        let installedVoices = voiceService.getPremiumVoices().filter { $0.isInstalled }
                                        let requestedVoiceId = character.customVoiceIdentifier ?? "com.apple.voice.premium.en-US.Zoe"

                                        // Auto-select fallback if requested voice isn't installed
                                        let actualVoiceId: String = {
                                            if voiceService.isVoiceInstalled(requestedVoiceId) {
                                                return requestedVoiceId
                                            } else {
                                                let fallbackVoice = voiceService.getBestAvailableVoice(preferredIdentifier: requestedVoiceId)
                                                return fallbackVoice.identifier
                                            }
                                        }()

                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Voice")
                                                .font(.caption)
                                                .foregroundColor(.secondary)

                                            Picker("Voice", selection: Binding(
                                                get: { actualVoiceId },
                                                set: { newValue in
                                                    character.customVoiceIdentifier = newValue
                                                    print("💾 Character voice set to: \(newValue)")
                                                }
                                            )) {
                                                ForEach(installedVoices, id: \.identifier) { voice in
                                                    Text(voice.name)
                                                        .tag(voice.identifier)
                                                }
                                            }
                                            .labelsHidden()

                                            // Show info if using fallback voice
                                            if requestedVoiceId != actualVoiceId {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "info.circle.fill")
                                                        .foregroundColor(.blue)
                                                        .font(.caption)
                                                    Text("Using fallback (requested voice not installed)")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                .padding(.top, 4)
                                            }
                                        }

                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text("Speech Rate")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                                Text(String(format: "%.2f", character.customSpeechRate ?? 0.52))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Slider(
                                                value: Binding(
                                                    get: { Double(character.customSpeechRate ?? 0.52) },
                                                    set: { newValue in
                                                        character.customSpeechRate = Float(newValue)
                                                    }
                                                ),
                                                in: 0.3...0.8,
                                                step: 0.05
                                            )
                                        }

                                        Text("Custom voice overrides the default voice from Settings")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                } else {
                                    Text("Using default voice from Settings")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .padding(16)
                    }
                }

                // Model Override
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "cpu.fill")
                                .foregroundColor(.pink)
                                .font(.title3)
                            Text("Custom Model")
                                .font(.headline)
                            Spacer()
                            Text("Optional")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Use custom model for this character", isOn: Binding(
                                get: { character.customModel != nil },
                                set: { enabled in
                                    withAnimation {
                                        if enabled {
                                            character.customModel = "gpt-4.1-mini"
                                        } else {
                                            character.customModel = nil
                                        }
                                    }
                                }
                            ))

                            if character.customModel != nil {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Model Name")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    TextField("Model", text: Binding(
                                        get: { character.customModel ?? "" },
                                        set: { character.customModel = $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)

                                    Text("e.g., gpt-4o, gpt-4o-mini, gpt-4, gpt-3.5-turbo")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Text("API URL and key use global settings")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .padding(20)
            .frame(minWidth: 350)  // Ensure content has minimum width
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // Fill available space
        .sheet(isPresented: $showingActivitySheet) {
            ActivityEditorSheet(
                character: $character,
                isPresented: $showingActivitySheet,
                editingActivity: editingActivity
            )
        }
        .alert("Delete Activity", isPresented: Binding(
            get: { activityToDelete != nil },
            set: { if !$0 { activityToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                activityToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let activity = activityToDelete {
                    withAnimation {
                        character.activities.removeAll { $0.id == activity.id }
                    }
                    activityToDelete = nil
                }
            }
        } message: {
            if let activity = activityToDelete {
                Text("Are you sure you want to delete '\(activity.name)'? This will remove all tracking history for this activity.")
            }
        }
    }
}

// MARK: - Activity Editor Sheet

struct ActivityEditorSheet: View {
    @Binding var character: Character
    @Binding var isPresented: Bool
    let editingActivity: Activity?

    @State private var name = ""
    @State private var description = ""
    @State private var frequency: ActivityFrequency = .daily
    @State private var customDays: Set<Int> = []
    @State private var hasNotification = false
    @State private var scheduledTime = Date()
    @State private var isTrackingEnabled = false

    init(character: Binding<Character>, isPresented: Binding<Bool>, editingActivity: Activity?) {
        _character = character
        _isPresented = isPresented
        self.editingActivity = editingActivity

        // Initialize state with editing activity if available
        if let activity = editingActivity {
            _name = State(initialValue: activity.name)
            _description = State(initialValue: activity.description)
            _frequency = State(initialValue: activity.frequency)
            _customDays = State(initialValue: activity.customDays ?? [])
            _hasNotification = State(initialValue: activity.scheduledTime != nil)
            _scheduledTime = State(initialValue: activity.scheduledTime ?? Date())
            _isTrackingEnabled = State(initialValue: activity.isTrackingEnabled)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(editingActivity == nil ? "Add Activity" : "Edit Activity")
                .font(.headline)
                .padding()

            Divider()

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Activity Name")
                            .font(.subheadline)
                        TextField("e.g., Exercise, Read, Daily Check-in", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.subheadline)
                        TextEditor(text: $description)
                            .frame(height: 60)
                            .font(.body)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        Text("e.g., '30 minutes of cardio'")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Enable Progress Tracking", isOn: $isTrackingEnabled)
                            .font(.subheadline)

                        VStack(alignment: .leading, spacing: 4) {
                            if isTrackingEnabled {
                                Text("✓ Shows in habit calendar")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("✓ Tracks completions, skips, and streaks")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("✓ Requires frequency selection")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("Simple one-time notification")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("No calendar tracking or streaks")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    if isTrackingEnabled {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Frequency")
                                .font(.subheadline)
                            Picker("Frequency", selection: $frequency) {
                                ForEach(ActivityFrequency.allCases, id: \.self) { freq in
                                    Text(freq.displayName).tag(freq)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()

                            if frequency == .custom {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Select Days")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
                                        DayToggle(dayNumber: 1, dayName: "Sun", customDays: $customDays)
                                        DayToggle(dayNumber: 2, dayName: "Mon", customDays: $customDays)
                                        DayToggle(dayNumber: 3, dayName: "Tue", customDays: $customDays)
                                        DayToggle(dayNumber: 4, dayName: "Wed", customDays: $customDays)
                                        DayToggle(dayNumber: 5, dayName: "Thu", customDays: $customDays)
                                        DayToggle(dayNumber: 6, dayName: "Fri", customDays: $customDays)
                                        DayToggle(dayNumber: 7, dayName: "Sat", customDays: $customDays)
                                    }
                                }
                                .padding(.top, 8)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Notification Reminder", isOn: $hasNotification)
                            .font(.subheadline)

                        if hasNotification {
                            VStack(alignment: .leading, spacing: 8) {
                                DatePicker("Time", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                                Text("Send a notification at the specified time")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button(editingActivity == nil ? "Add" : "Save") {
                    saveActivity()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                         (frequency == .custom && customDays.isEmpty))
            }
            .padding()
        }
        .frame(width: 500, height: 550)
        .padding()
    }

    private func saveActivity() {
        var updatedCharacter = character

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedDescription = description.trimmingCharacters(in: .whitespaces)

        if let editingActivity = editingActivity {
            // Edit existing activity
            if let index = updatedCharacter.activities.firstIndex(where: { $0.id == editingActivity.id }) {
                updatedCharacter.activities[index].name = trimmedName
                updatedCharacter.activities[index].description = trimmedDescription
                updatedCharacter.activities[index].frequency = frequency
                updatedCharacter.activities[index].customDays = frequency == .custom ? customDays : nil
                updatedCharacter.activities[index].scheduledTime = hasNotification ? scheduledTime : nil
                updatedCharacter.activities[index].isTrackingEnabled = isTrackingEnabled
            }
        } else {
            // Add new activity
            let newActivity = Activity(
                name: trimmedName,
                description: trimmedDescription,
                scheduledTime: hasNotification ? scheduledTime : nil,
                frequency: frequency,
                customDays: frequency == .custom ? customDays : nil,
                isTrackingEnabled: isTrackingEnabled,
                isEnabled: true
            )
            updatedCharacter.activities.append(newActivity)
        }

        // Update the binding (this triggers AppDelegate's updateCharacter which schedules activities)
        character = updatedCharacter

        isPresented = false
    }
}

// Helper view for day selection
struct DayToggle: View {
    let dayNumber: Int
    let dayName: String
    @Binding var customDays: Set<Int>

    var isSelected: Bool {
        customDays.contains(dayNumber)
    }

    var body: some View {
        Button(action: {
            if isSelected {
                customDays.remove(dayNumber)
            } else {
                customDays.insert(dayNumber)
            }
        }) {
            Text(dayName)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - API Settings Tab

struct APISettingsTab: View {
    var appDelegate: AppDelegate
    @ObservedObject var appState: AppState
    @State private var apiURL: String
    @State private var apiKey: String
    @State private var model: String
    @State private var useStreaming: Bool
    @State private var temperature: Double
    @State private var apiKeyError: String?
    @State private var showingSaveSuccess = false
    @FocusState private var apiKeyFieldFocused: Bool
    @State private var saveDebounceTask: DispatchWorkItem?

    init(appDelegate: AppDelegate, appState: AppState) {
        self.appDelegate = appDelegate
        self._appState = ObservedObject(wrappedValue: appState)
        _apiURL = State(initialValue: appState.settings.globalAPIConfig.apiURL)
        _model = State(initialValue: appState.settings.globalAPIConfig.model)
        // Load from Keychain, or show empty if no key
        _apiKey = State(initialValue: "")
        _useStreaming = State(initialValue: appState.settings.globalAPIConfig.useStreaming)
        _temperature = State(initialValue: appState.settings.globalAPIConfig.temperature)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("OpenAI API Configuration") {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("API URL", text: $apiURL)
                                .onChange(of: apiURL) { saveSettings() }
                            Text("Default: https://api.openai.com/v1")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            TextField(
                                appState.settings.globalAPIConfig.hasAPIKey ? "API Key (configured - enter new to replace)" : "Enter API Key (e.g., sk-...)",
                                text: $apiKey
                            )
                            .textFieldStyle(.roundedBorder)
                            .focused($apiKeyFieldFocused)
                            .onChange(of: apiKey) { oldValue, newValue in
                                // Cancel any pending save
                                saveDebounceTask?.cancel()

                                // Clear previous errors/success when user types
                                apiKeyError = nil
                                showingSaveSuccess = false

                                // Debounce: save after 1 second of no typing (or on paste)
                                let task = DispatchWorkItem {
                                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.isEmpty && trimmed.count >= 20 {
                                        saveAPIKey(trimmed)
                                    }
                                }
                                saveDebounceTask = task
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: task)
                            }
                            .onChange(of: apiKeyFieldFocused) { oldValue, newValue in
                                // Save immediately when field loses focus (user clicks away)
                                if oldValue && !newValue && !apiKey.isEmpty {
                                    saveDebounceTask?.cancel()  // Cancel debounce
                                    saveAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
                                }
                            }
                            .onSubmit {
                                // Save immediately when user presses Enter
                                saveDebounceTask?.cancel()  // Cancel debounce
                                saveAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
                            }

                            // Show error if validation failed
                            if let error = apiKeyError {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }

                            // Show success message
                            if showingSaveSuccess {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text("API key saved successfully!")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }

                            // Show configured status
                            if appState.settings.globalAPIConfig.hasAPIKey && !showingSaveSuccess {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text("API key is configured and stored securely in Keychain")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Text("Your OpenAI API key from platform.openai.com (stored securely in Keychain)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Model", text: $model)
                                .onChange(of: model) { saveSettings() }
                            Text("e.g., gpt-4.1, gpt-4.1-mini (auto-switches after 10 messages)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Use Streaming", isOn: $useStreaming)
                                .onChange(of: useStreaming) { saveSettings() }
                            Text("Enable real-time streaming responses (disable if your API doesn't support it)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Temperature")
                                Spacer()
                                Text(String(format: "%.1f", temperature))
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $temperature, in: 0.0...2.0, step: 0.1)
                                .onChange(of: temperature) { saveSettings() }
                            Text("Controls randomness: 0.0 = focused/deterministic, 2.0 = creative/random (default: 0.7)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Message History Count")
                                Spacer()
                                Stepper("\(appState.settings.messageHistoryCount)", value: $appState.settings.messageHistoryCount, in: 5...50)
                                    .onChange(of: appState.settings.messageHistoryCount) {
                                        StorageService.shared.saveSettings(appState.settings)
                                    }
                            }
                            Text("Number of previous messages to include in each request (affects context and API cost)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Auto-switch to mini after 10 messages", isOn: $appState.settings.autoSwitchToMini)
                                .onChange(of: appState.settings.autoSwitchToMini) { _ in
                                    StorageService.shared.saveSettings(appState.settings)
                                }
                            Text("Automatically switch from gpt-4.1 to gpt-4.1-mini after 10 messages for cost savings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
    }

    func saveSettings() {
        // Auto-save API config on any change (except API key - handled separately)
        appState.settings.globalAPIConfig.apiURL = apiURL
        appState.settings.globalAPIConfig.model = model
        appState.settings.globalAPIConfig.useStreaming = useStreaming
        appState.settings.globalAPIConfig.temperature = temperature

        StorageService.shared.saveSettings(appState.settings)
    }

    func saveAPIKey(_ key: String) {
        // Clear any previous errors
        apiKeyError = nil
        showingSaveSuccess = false

        // Only save if not empty
        guard !key.isEmpty else {
            apiKey = ""
            return
        }

        // Validate API key format for OpenAI
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)

        // Basic validation
        if trimmedKey.count < 20 {
            apiKeyError = "API key is too short. OpenAI keys are usually 50+ characters."
            LoggerService.storage.warning("⚠️ API key validation failed: too short (\(trimmedKey.count) chars)")
            return
        }

        // OpenAI-specific validation (if using OpenAI URL)
        if apiURL.lowercased().contains("openai.com") {
            if !trimmedKey.hasPrefix("sk-") && !trimmedKey.hasPrefix("sk-proj-") {
                apiKeyError = "OpenAI API keys must start with 'sk-' or 'sk-proj-'"
                LoggerService.storage.warning("⚠️ API key validation failed: doesn't start with sk-")
                return
            }
        }

        // Save API key to Keychain
        LoggerService.storage.info("💾 Saving API key to Keychain...")
        appState.settings.globalAPIConfig.setAPIKey(trimmedKey)
        StorageService.shared.saveSettings(appState.settings)

        // Show success message
        showingSaveSuccess = true
        LoggerService.storage.info("✅ API key saved successfully to Keychain")

        // Clear the text field after saving
        apiKey = ""

        // Hide success message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            showingSaveSuccess = false
        }
    }
}

// MARK: - General Settings Tab

struct GeneralSettingsTab: View {
    var appDelegate: AppDelegate
    @ObservedObject var appState: AppState
    @State private var launchError: String?
    @ObservedObject private var activityService = ActivityService.shared
    @ObservedObject private var updateService = UpdateService.shared
    @ObservedObject private var voiceService = VoiceService.shared
    @State private var showVoiceDownloadAlert = false
    @State private var selectedVoiceNeedsDownload = false

    init(appDelegate: AppDelegate, appState: AppState) {
        self.appDelegate = appDelegate
        self._appState = ObservedObject(wrappedValue: appState)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Application") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Launch on Startup", isOn: $appState.settings.launchOnStartup)
                            .onChange(of: appState.settings.launchOnStartup) { oldValue, newValue in
                                toggleLaunchOnStartup(enabled: newValue)
                                StorageService.shared.saveSettings(appState.settings)
                            }

                        if let error = launchError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                }

                GroupBox("Notifications") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            if activityService.notificationPermissionGranted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Notifications Enabled")
                                    .foregroundColor(.secondary)
                            } else {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Notifications Disabled")
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if !activityService.notificationPermissionGranted {
                                Button("Enable in System Settings") {
                                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                            }
                        }

                        if !activityService.notificationPermissionGranted {
                            Text("Activity notifications require notification permission. Click above to open System Settings → Notifications.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }

                GroupBox("Updates") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Automatically check for updates", isOn: $appState.settings.autoUpdateEnabled)
                            .onChange(of: appState.settings.autoUpdateEnabled) { oldValue, newValue in
                                updateService.setAutoUpdateEnabled(newValue)
                                StorageService.shared.saveSettings(appState.settings)
                            }

                        if appState.settings.autoUpdateEnabled {
                            Text("Checks daily for new versions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current version: \(updateService.versionString)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if let lastCheck = updateService.lastCheckDate {
                                    Text("Last checked: \(lastCheck, formatter: updateDateFormatter)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Button(action: {
                                updateService.checkForUpdates()
                            }) {
                                if updateService.isCheckingForUpdates {
                                    HStack {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                        Text("Checking...")
                                    }
                                } else {
                                    Text("Check for Updates")
                                }
                            }
                            .disabled(updateService.isCheckingForUpdates)
                        }

                        Text("WigiAI uses Sparkle for secure automatic updates from GitHub.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                GroupBox(content: {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label("Voice Interaction", systemImage: "mic.fill")
                                .font(.headline)
                            Spacer()
                            Text("EXPERIMENTAL")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(4)
                        }

                        Divider()

                        Toggle("Enable Voice Features", isOn: $appState.settings.voiceSettings.enabled)
                            .onChange(of: appState.settings.voiceSettings.enabled) {
                                StorageService.shared.saveSettings(appState.settings)
                            }

                        if appState.settings.voiceSettings.enabled {
                            VStack(alignment: .leading, spacing: 12) {
                                Divider()

                                HStack {
                                    Text("Features:")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }

                                Toggle("Speech-to-Text (Push-to-Talk)", isOn: $appState.settings.voiceSettings.sttEnabled)
                                    .onChange(of: appState.settings.voiceSettings.sttEnabled) {
                                        StorageService.shared.saveSettings(appState.settings)
                                    }

                                Toggle("Text-to-Speech (AI Responses)", isOn: $appState.settings.voiceSettings.ttsEnabled)
                                    .onChange(of: appState.settings.voiceSettings.ttsEnabled) {
                                        StorageService.shared.saveSettings(appState.settings)
                                    }

                                Toggle("Auto-Submit After Voice Input", isOn: $appState.settings.voiceSettings.autoSubmitAfterVoice)
                                    .onChange(of: appState.settings.voiceSettings.autoSubmitAfterVoice) {
                                        StorageService.shared.saveSettings(appState.settings)
                                    }

                                Divider()

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Default Voice (Premium Only)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                    let premiumVoices = voiceService.getPremiumVoices()
                                    let requestedVoiceId = appState.settings.voiceSettings.voiceIdentifier ?? "com.apple.voice.premium.en-US.Zoe"

                                    // Auto-select fallback if requested voice isn't installed
                                    let actualVoiceId: String = {
                                        if voiceService.isVoiceInstalled(requestedVoiceId) {
                                            return requestedVoiceId
                                        } else {
                                            // Get the fallback voice that will actually be used
                                            let fallbackVoice = voiceService.getBestAvailableVoice(preferredIdentifier: requestedVoiceId)
                                            return fallbackVoice.identifier
                                        }
                                    }()

                                    Picker("Voice", selection: Binding(
                                        get: { actualVoiceId },
                                        set: { newValue in
                                            // Check if voice is installed
                                            if !voiceService.isVoiceInstalled(newValue) {
                                                showVoiceDownloadAlert = true
                                                selectedVoiceNeedsDownload = true
                                            } else {
                                                selectedVoiceNeedsDownload = false
                                            }
                                            appState.settings.voiceSettings.voiceIdentifier = newValue
                                            StorageService.shared.saveSettings(appState.settings)
                                        }
                                    )) {
                                        ForEach(premiumVoices, id: \.identifier) { voice in
                                            HStack {
                                                Text(voice.name)
                                                Spacer()
                                                if voice.isInstalled {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.green)
                                                        .font(.caption)
                                                } else {
                                                    Image(systemName: "arrow.down.circle")
                                                        .foregroundColor(.orange)
                                                        .font(.caption)
                                                }
                                            }
                                            .tag(voice.identifier)
                                        }
                                    }
                                    .labelsHidden()

                                    // Show info if using fallback voice
                                    if requestedVoiceId != actualVoiceId {
                                        HStack(spacing: 6) {
                                            Image(systemName: "info.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.caption)
                                            Text("Using fallback voice (requested voice not installed)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.top, 4)
                                    }

                                    // Explanatory text about character overrides
                                    Text("This is the default voice. Each character can override it with a custom voice.")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)

                                    // Prominent recommendation if no premium voices installed
                                    if !voiceService.hasPremiumVoiceInstalled() {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "star.circle.fill")
                                                    .foregroundColor(.yellow)
                                                    .font(.title3)
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Download Premium Voices for Best Quality")
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                    Text("Premium voices are free and sound much more natural than the default voice.")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(12)
                                            .background(Color.yellow.opacity(0.15))
                                            .cornerRadius(8)

                                            Button(action: {
                                                // Open System Settings to Accessibility > Spoken Content
                                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?Seeing_VoiceOver") {
                                                    NSWorkspace.shared.open(url)
                                                }
                                            }) {
                                                Label("Open System Settings to Download", systemImage: "arrow.down.circle.fill")
                                                    .font(.subheadline)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.blue)
                                        }
                                        .padding(.top, 8)
                                    } else {
                                        Button(action: {
                                            // Open System Settings to Accessibility > Spoken Content
                                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?Seeing_VoiceOver") {
                                                NSWorkspace.shared.open(url)
                                            }
                                        }) {
                                            Label("Download More Voices", systemImage: "arrow.down.circle")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.link)
                                    }

                                    Text("All premium voices are free but require download from System Settings. ✓ = Installed, ↓ = Needs Download")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Divider()

                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Speech Rate")
                                        Spacer()
                                        Text(String(format: "%.2f", appState.settings.voiceSettings.speechRate))
                                            .foregroundColor(.secondary)
                                    }
                                    Slider(value: $appState.settings.voiceSettings.speechRate, in: 0.3...0.8, step: 0.05)
                                        .onChange(of: appState.settings.voiceSettings.speechRate) {
                                            StorageService.shared.saveSettings(appState.settings)
                                        }
                                    Text("Adjust how fast the AI speaks (0.3 = slow, 0.8 = fast)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Divider()

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Uses macOS built-in speech recognition and text-to-speech. Hold the microphone button to speak, use the speaker button to toggle voice responses.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding()
                })
            }
            .padding()
        }
        .alert("Voice Not Installed", isPresented: $showVoiceDownloadAlert) {
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?Seeing_VoiceOver") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("The selected premium voice is not installed on your Mac. Download it from System Settings → Accessibility → Spoken Content → System Voice for the best quality.")
        }
    }

    func toggleLaunchOnStartup(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status == .enabled {
                        return
                    }
                    try SMAppService.mainApp.register()
                    launchError = nil
                } else {
                    if SMAppService.mainApp.status == .notRegistered {
                        return
                    }
                    try SMAppService.mainApp.unregister()
                    launchError = nil
                }
            } catch {
                launchError = "Failed to update launch on startup: \(error.localizedDescription)"
                appState.settings.launchOnStartup = !enabled
            }
        }
    }
}


// MARK: - Date Formatter

private let updateDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()
