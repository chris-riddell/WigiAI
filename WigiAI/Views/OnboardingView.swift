//
//  OnboardingView.swift
//  WigiAI
//
//  Onboarding flow for first-time users
//

import SwiftUI

struct OnboardingView: View {
    var appDelegate: AppDelegate
    @ObservedObject var appState: AppState
    @Binding var isPresented: Bool

    @State private var currentStep = 0
    @State private var apiURL: String
    @State private var apiKey: String = ""
    @State private var model: String
    @State private var characterName: String = ""
    @State private var selectedAvatar: String = "person"
    @State private var isAPIKeyValid = false

    init(appDelegate: AppDelegate, appState: AppState, isPresented: Binding<Bool>) {
        self.appDelegate = appDelegate
        self._appState = ObservedObject(wrappedValue: appState)
        self._isPresented = isPresented
        _apiURL = State(initialValue: appState.settings.globalAPIConfig.apiURL)
        _model = State(initialValue: appState.settings.globalAPIConfig.model)

        // Check if API key is already configured
        _isAPIKeyValid = State(initialValue: appState.settings.globalAPIConfig.hasAPIKey)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Simple compact progress indicator
            HStack(spacing: 8) {
                ForEach(0..<4) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 16)

            // Content - wrapped in ScrollView to ensure accessibility
            ScrollView {
                Group {
                    switch currentStep {
                    case 0:
                        WelcomeStep()
                    case 1:
                        APISetupStep(appState: appState, apiURL: $apiURL, apiKey: $apiKey, model: $model, isAPIKeyValid: $isAPIKeyValid)
                    case 2:
                        CreateCharacterStep(appDelegate: appDelegate, appState: appState, characterName: $characterName, selectedAvatar: $selectedAvatar)
                    case 3:
                        FeaturesStep()
                    default:
                        WelcomeStep()
                    }
                }
                .frame(height: 500)
                .animation(.easeInOut(duration: 0.3), value: currentStep)
            }

            // Navigation buttons - prominent and visible
            Divider()

            HStack(spacing: 16) {
                if currentStep > 0 {
                    Button(action: {
                        withAnimation {
                            currentStep -= 1
                        }
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .frame(minWidth: 100)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Spacer()

                if currentStep < 3 {
                    Button(action: {
                        withAnimation {
                            if currentStep == 1 {
                                // Save API settings
                                appState.settings.globalAPIConfig.apiURL = apiURL
                                appState.settings.globalAPIConfig.model = model

                                // CRITICAL: Only update API key if user entered a new one
                                // (Don't overwrite existing key with empty string)
                                if !apiKey.isEmpty {
                                    appState.settings.globalAPIConfig.setAPIKey(apiKey)
                                }

                                StorageService.shared.saveSettings(appState.settings)
                            }
                            currentStep += 1
                        }
                    }) {
                        HStack {
                            Text("Continue")
                            Image(systemName: "chevron.right")
                        }
                        .frame(minWidth: 120)
                        .padding(.horizontal, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.blue)
                    .disabled(currentStep == 1 && !appState.settings.globalAPIConfig.hasAPIKey && (apiKey.isEmpty || !isAPIKeyValid))
                } else {
                    Button(action: {
                        completeOnboarding()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Get Started")
                        }
                        .frame(minWidth: 140)
                        .padding(.horizontal, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.green)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 700, minHeight: 750)
    }

    func stepTitle(for index: Int) -> String {
        switch index {
        case 0: return "Welcome"
        case 1: return "API Setup"
        case 2: return "Character"
        case 3: return "Features"
        default: return ""
        }
    }

    func completeOnboarding() {
        // Create character if name was provided
        if !characterName.isEmpty {
            // Use smart positioning for first character
            let position = appDelegate.calculateSmartPosition()

            let newCharacter = Character(
                name: characterName,
                masterPrompt: "You are a friendly AI companion who helps with daily check-ins and habit tracking.",
                avatarAsset: selectedAvatar,
                position: position
            )
            appDelegate.appState.addCharacter(newCharacter)
            appDelegate.createCharacterWidget(for: newCharacter)
        }

        // Mark onboarding as complete
        appDelegate.appState.updateSettings { settings in
            settings.hasCompletedOnboarding = true
        }

        // Close onboarding
        isPresented = false
    }
}

// MARK: - Welcome Step

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon/logo
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }

            VStack(spacing: 12) {
                Text("Welcome to WigiAI")
                    .font(.system(size: 36, weight: .bold))

                Text("Your AI companions for daily habits and check-ins")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "bubble.left.and.bubble.right.fill", title: "Natural Conversations", description: "Chat with your AI companions naturally")
                FeatureRow(icon: "bell.badge.fill", title: "Smart Reminders", description: "Get personalized check-ins throughout your day")
                FeatureRow(icon: "person.2.fill", title: "Multiple Characters", description: "Create different companions for different purposes")
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }
}

// MARK: - API Setup Step

struct APISetupStep: View {
    @ObservedObject var appState: AppState
    @Binding var apiURL: String
    @Binding var apiKey: String
    @Binding var model: String
    @Binding var isAPIKeyValid: Bool
    @State private var apiKeyError: String?
    @State private var showingSaveSuccess = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            VStack(spacing: 8) {
                Text("Connect Your AI")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Enter your OpenAI API credentials to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API URL")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("https://api.openai.com/v1", text: $apiURL)
                            .textFieldStyle(.roundedBorder)
                        Text("Use OpenAI or any compatible API endpoint")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField(
                            appState.settings.globalAPIConfig.hasAPIKey ? "API Key (already configured)" : "sk-...",
                            text: $apiKey
                        )
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: apiKey) { oldValue, newValue in
                                // Clear previous errors
                                apiKeyError = nil
                                showingSaveSuccess = false
                                isAPIKeyValid = false

                                // Validate as user types/pastes
                                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

                                // Only validate if there's content
                                if !trimmed.isEmpty {
                                    if trimmed.count < 20 {
                                        apiKeyError = "API key is too short (minimum 20 characters)"
                                    } else if apiURL.lowercased().contains("openai.com") && !trimmed.hasPrefix("sk-") && !trimmed.hasPrefix("sk-proj-") {
                                        apiKeyError = "OpenAI API keys must start with 'sk-' or 'sk-proj-'"
                                    } else {
                                        // Valid format!
                                        showingSaveSuccess = true
                                        isAPIKeyValid = true
                                    }
                                }
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

                        // Show success indicator
                        if showingSaveSuccess {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("API key format looks good!")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }

                        // Show "already configured" message
                        if apiKey.isEmpty && appState.settings.globalAPIConfig.hasAPIKey && apiKeyError == nil {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("API key is already configured and stored securely")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        } else if !showingSaveSuccess && apiKeyError == nil {
                            Text("Get your API key from platform.openai.com")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Model")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("gpt-4o", text: $model)
                            .textFieldStyle(.roundedBorder)
                        Text("Recommended: gpt-4o for speed and cost")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Create Character Step

struct CreateCharacterStep: View {
    var appDelegate: AppDelegate
    @ObservedObject var appState: AppState
    @Binding var characterName: String
    @Binding var selectedAvatar: String
    @State private var showingLibrary = false

    let avatars = [
        ("person", "🧑", "Person"),
        ("professional", "👨‍💼", "Professional"),
        ("scientist", "🧑‍🔬", "Scientist"),
        ("artist", "🧑‍🎨", "Artist")
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.purple)

            VStack(spacing: 8) {
                Text("Create Your First Character")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Give your AI companion a name and appearance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Character Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("e.g., Coach, Assistant, Friend", text: $characterName)
                            .textFieldStyle(.roundedBorder)
                        Text("Choose a name that reflects their purpose")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Avatar Style")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                            ForEach(avatars, id: \.0) { avatar in
                                AvatarOption(
                                    emoji: avatar.1,
                                    title: avatar.2,
                                    isSelected: selectedAvatar == avatar.0
                                ) {
                                    withAnimation {
                                        selectedAvatar = avatar.0
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .padding(.horizontal, 40)

            // Divider with "OR" text
            HStack {
                VStack { Divider() }
                Text("OR")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                VStack { Divider() }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 12)

            // Template Library Button - More Prominent
            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("Choose from Pre-Built Templates")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("10 ready-to-use AI companions for productivity, health, and more")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button(action: { showingLibrary = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 16))
                        Text("Browse Character Library")
                            .fontWeight(.semibold)
                    }
                    .frame(minWidth: 250)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.purple)
            }
            .padding(.horizontal, 40)

            Text("You can skip this and create characters later")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingLibrary) {
            CharacterLibraryView(appDelegate: appDelegate, appState: appState)
                .frame(minWidth: 900, idealWidth: 1000, maxWidth: .infinity, minHeight: 700, idealHeight: 800, maxHeight: .infinity)
        }
    }
}

// MARK: - Features Step

struct FeaturesStep: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(.yellow)

            VStack(spacing: 8) {
                Text("You're All Set!")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Here's what you can do with WigiAI")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 20) {
                FeatureHighlight(
                    icon: "bubble.left.and.bubble.right.fill",
                    iconColor: .blue,
                    title: "Click to Chat",
                    description: "Click any character widget to start a conversation"
                )

                FeatureHighlight(
                    icon: "bell.fill",
                    iconColor: .orange,
                    title: "Set Reminders",
                    description: "Configure custom check-in times in Settings"
                )

                FeatureHighlight(
                    icon: "arrow.up.forward.app.fill",
                    iconColor: .green,
                    title: "Drag Anywhere",
                    description: "Move character widgets anywhere on your screen"
                )

                FeatureHighlight(
                    icon: "gearshape.fill",
                    iconColor: .gray,
                    title: "Customize",
                    description: "Access Settings from the menubar icon"
                )
            }
            .padding(.horizontal, 60)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct AvatarOption: View {
    let emoji: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 40))

                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct FeatureHighlight: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}
