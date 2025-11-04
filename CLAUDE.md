# WigiAI - AI Companion Desktop Widget

## Project Overview
A macOS native app featuring AI-powered character companions that live on your desktop, providing habit tracking through conversational check-ins and proactive notifications.

**Current Version:** 1.0.6
**Status:** ✅ Production Ready with Auto-Updates

## Core Features

### Character System
- **Desktop widgets** - Draggable companions with persistent positions
- **4 avatar styles** - Person, Professional, Scientist, Artist (emoji-based with gradients)
- **10 built-in templates** - Executive Assistant, Fitness Coach, Sleep Optimizer, Study Buddy, Writing Coach, Mindfulness Guide, Budget Tracker, Meal Prep Partner, Focus Guardian, Habit Builder
- **Per-character configuration** - Independent prompts, models, voices, and habits

### AI Conversation
- **OpenAI-compatible APIs** - Works with OpenAI, Ollama, local servers
- **Real-time streaming** - SSE-based with toggle option
- **Smart context management** - Incremental updates with prompt caching (50% cost savings)
- **Smart model switching** - Auto-switch from gpt-4.1 to gpt-4.1-mini after 10 messages (optional, respects custom models)
- **Suggested replies** - AI-generated quick response buttons
- **Temperature control** - Adjustable creativity (0.0-2.0, default 0.7)

### Habit Tracking
- **Conversational tracking** - AI naturally asks about and tracks habits
- **Flexible scheduling** - Daily, weekdays, weekends, or custom days
- **Visual progress** - 7-day calendar with color-coded completion
- **Quick-add from chat** - Add new activities directly from habit progress dropdown
- **Celebrations** - Confetti animations with streak milestones
- **Reminder notifications** - Optional per-habit reminders

### Voice Interaction (EXPERIMENTAL)
- **Speech-to-Text** - Push-to-talk with native macOS APIs (offline, zero cost)
- **Text-to-Speech** - 10 premium voices (Ava, Evan, Joelle, Nathan, Noel, Zoe, Fiona, Malcolm, Stephanie, Matilda)
- **Per-character voices** - Optional voice overrides

### Data & Settings
- **Multi-file JSON storage** - Individual character files for scalability
- **Automatic migration** - Seamless upgrade from single-file format
- **Launch on startup** - SMAppService integration (macOS 13+)
- **Auto-updates** - Sparkle framework with daily checks from GitHub releases

## Technical Architecture

### Tech Stack
- **Language:** Swift (native macOS)
- **UI Framework:** SwiftUI
- **Minimum OS:** macOS 14.0+ (Sonoma)
- **Dependencies:** Sparkle framework for auto-updates

### Project Structure
```
WigiAI/
├── Models/              Character, Message, Activity, AppSettings, CharacterTemplate, AppState
├── Views/               CharacterWidget, ChatWindow, SettingsWindow, CharacterLibraryView
│   └── ViewModifiers/   WindowMoveObserver (reusable view logic)
├── Services/            AIService, StorageService, ActivityService, VoiceSessionManager
├── Utilities/           Strings (centralized localization)
├── CharacterTemplates/  10 pre-built character JSON templates (folder reference required)
└── Assets.xcassets/     App icons and menu bar icons
```

**IMPORTANT:** The `CharacterTemplates/` folder must be added to Xcode as a folder reference (blue folder).

### Testing
- **Comprehensive unit tests** across 7 test suites
- Coverage: AIServiceTests, CharacterTemplateTests, CharacterTests, HabitTests, MessageTests, ReminderTests, StorageServiceTests
- Run tests: `xcodebuild test -scheme WigiAI -destination 'platform=macOS'`

### Data Models

**Core Models:**
- **AppState** - `@MainActor ObservableObject` centralized state container
- **Character** - name, masterPrompt, avatarAsset, position, activities[], chatHistory, persistentContext, voiceSettings, customModel
- **Activity** - Unified reminder + habit tracking model
  - name, description, scheduledTime (optional)
  - isTrackingEnabled (toggle for habit features)
  - frequency (ActivityFrequency enum)
  - completionDates, skipDates, currentStreak (when tracking enabled)
  - category, icon, color (for organization)
- **Message** - role ("user" | "assistant"), content, timestamp

**Configuration:**
- **AppSettings** - globalAPIConfig, characterIds (UUIDs only), voiceSettings, autoUpdateEnabled, autoSwitchToMini
- **APIConfig** - apiURL, apiKey, model (default: gpt-4.1), temperature, useStreaming
- **VoiceSettings** - Global and per-character voice configuration (voice name, speed, enabled state)
- **CharacterTemplate** - id, name, category, description, avatar, masterPrompt, activities[]

**Enums:**
- **ActivityFrequency** - `.daily`, `.weekdays`, `.weekends`, `.custom([Int])`, `.oneTime`
- **AvatarAsset** - `.person`, `.professional`, `.scientist`, `.artist`

## Key Technical Decisions

### Storage Architecture: Multi-File JSON
**Why multi-file over single-file or SQLite?**
- **Scalability**: Individual files prevent large chat histories from slowing entire app
- **Performance**: Only modified characters saved, not entire app state
- **Data safety**: Corruption isolated to single character
- **Human-readable**: Easy debugging and data portability
- **Simplicity**: No database setup, automatic migrations

**File Structure:**
```
~/Library/Application Support/WigiAI/
├── app_settings.json          # Global settings + character UUIDs only
├── characters/                # Individual character files
│   └── {UUID}.json           # Self-contained character state
└── backups/                   # Automatic backups before saves
```

### Services Architecture

The app is built with a service-oriented architecture for separation of concerns:

**Core Services:**
- **AIService** - OpenAI API communication, streaming responses, context management, prompt caching
- **StorageService** - Multi-file JSON persistence, backup/recovery, character file management
- **ActivityService** - Unified notification scheduling for activities (reminders + habits)
- **CharacterTemplateService** - Loads and manages 10 built-in character templates from JSON files

**Voice Services:**
- **VoiceService** - Text-to-speech with 10 premium voices, per-character voice settings
- **VoiceSessionManager** - Speech-to-text session management, push-to-talk coordination

**Utility Services:**
- **LoggerService** - Category-based logging with emoji prefixes (chat, ai, voice, storage, habits, reminders, sound, ui, app, updates)
- **KeychainService** - Secure API key storage in macOS Keychain (prevents keys in JSON/logs)
- **UpdateService** - Sparkle framework integration for auto-update checks and installation
- **SoundEffects** - System sound feedback (message sent/received, success, celebration, streak milestones)
- **ReminderService** - Notification permission management and delegation

### Utilities

**Strings** - Centralized string constants and localization helpers
- Provides consistent error messages and UI text
- Prepared for future multi-language support

**Scripts** (`/scripts/` directory)
- `deploy.sh` - Local build and installation to /Applications
- `bump_version.sh` - Automated version bumping, tagging, and GitHub push
- `generate_appcast.rb` - Auto-generates appcast.xml from GitHub releases (CI only)
- Icon generation utilities

### Context Management Strategy
- **System prompt:** Character's master prompt (cached by OpenAI for 50% cost reduction)
- **Persistent context:** Auto-updated summary (bullet points, incremental merge)
- **Recent history:** Last 10 messages (configurable)
- **Background updates:** Debounced every 5 minutes OR 5 messages (not tied to window close)
- **Activity injection:** Separate from persistent context to preserve prompt cache

### State Management Pattern
**Dedicated AppState class for separation of concerns:**

- **AppState** (`@MainActor class`): Centralized state container
  - `@Published var settings: AppSettings`
  - `@Published var characters: [Character]` (loaded from individual files)
  - Methods: `addCharacter()`, `updateCharacter()`, `deleteCharacter()`, `updateSettings()`

- **AppDelegate**: App lifecycle management (NOT an ObservableObject)
  - Owns `appState: AppState!`
  - Manages windows, widgets, notifications
  - Delegates state operations to `appState`

- **Views**: Observe AppState directly
  - Pattern: `var appDelegate: AppDelegate` + `@ObservedObject var appState: AppState`
  - Access: `appState.characters`, `appState.settings`
  - Updates: `appState.updateCharacter()`, etc.

- **StorageService**: Multi-file persistence
  - Individual character files: `saveCharacter()`, `loadCharacter()`
  - Settings management: `saveSettings()`, `loadSettings()`
  - Backup/recovery system with `Result<Void, Error>` error propagation

**Update Flow:**
```
User Action → appState.updateCharacter() → StorageService.saveCharacter()
                                        ↓
                            Verify UUID in settings.characterIds
                                        ↓
                            @Published triggers View updates
```

### Views Architecture

**Main Windows:**
- **OnboardingView** - 4-step first-run experience (API setup, character creation, template library, completion)
- **SettingsWindow** - Comprehensive settings interface with tabs for global API config, characters, activities, voice
- **CharacterLibraryView** - Template browser with 10 pre-built character templates

**Character Interaction:**
- **CharacterWidget** - Desktop widget with avatar, animations, and click interactions
- **ChatWindow** - Main conversation interface with message history and input
- **ChatViewModel** - Business logic (~600+ lines): AI communication, context updates, voice coordination

**Chat Components:**
- **ChatHeaderView** - Character name, actions (habit progress, settings, clear chat)
- **MessageListView** - Scrollable message display with animations and streaming
- **ChatInputView** - Text input area with voice button and send functionality
- **SuggestedRepliesView** - AI-generated quick response buttons

**Activity Tracking:**
- **HabitProgressView** - 7-day calendar visualization with quick-add button
- **HabitQuickActions** - Pending activity buttons with complete/skip/snooze actions
- **CelebrationView** - Confetti animations for completions and streak milestones
- **ActivityEditorSheet** - Form for creating/editing activities (reused in Settings and quick-add)

**View Modifiers:**
- **WindowMoveObserver** - Reusable position tracking with debouncing (500ms)

### Window Architecture
- **CharacterPanel**: Custom NSPanel (non-activating, stationary, draggable)
- **ChatPanel**: Custom NSPanel (activating, resizable, non-blocking close)
- **Position saving**: Debounced 500ms to prevent excessive disk writes on drag

## Recent Major Changes

### GPT-4.1 & UX Improvements (Oct 30, 2025)

**Model Updates:**
- Updated default model from gpt-4o to **gpt-4.1**
- Added **auto-switch feature**: Optionally switch from gpt-4.1 to gpt-4.1-mini after 10 messages for cost savings
  - Respects custom model settings (only applies when using global default)
  - Configurable via toggle in Settings and Onboarding
  - Intelligent: Waits until initial character establishment is complete

**AI Context Enhancements:**
- **Shortened communication style**: "Be conversational, brief, and punchy - but prioritize being smart and helpful over being short"
- **Enhanced persistent context prompt**: Now captures 7 priority areas with specific guidance
  - User's goals & intentions, patterns & preferences, current situation
  - Progress & history, important facts, emotional context, decisions & commitments
  - Emphasizes specificity ("Exercise 3x/week" not "Exercise regularly")
  - Includes temporal details and motivations for deeper understanding

**UI/UX Improvements:**
- **Dark mode contrast fix**: AI message bubbles now have better visibility in dark mode
- **Quick-add activities**: New "+" button in Habit Progress view to add activities without opening Settings
  - Reuses ActivityEditorSheet component for consistency
  - Streamlines workflow for creating tracked habits

**Code Quality:**
- Removed all backward compatibility code (app unreleased, no migration needed)
- Deleted ActivityMigration.swift and deprecated properties (~522 lines removed)
- Zero deprecation warnings

### Activity Unification (Oct 29, 2025)

**Unified Reminder + Habit → Activity model for simplicity and flexibility**

**Why unify?**
- Reminders and Habits had significant overlap (time, notifications, enablement)
- Confusing UX: "Do I create a Reminder or a Habit?"
- Rigid: Couldn't have reminders that track completion
- Management overhead: Syncing reminder times with habit schedules

**New Activity Model:**
```swift
struct Activity {
    let id: UUID
    var name: String               // "Morning Exercise"
    var description: String         // "30 mins cardio"
    var scheduledTime: Date?        // Optional notification time
    var frequency: ActivityFrequency  // daily, weekdays, weekends, custom, oneTime
    var isTrackingEnabled: Bool     // Toggle: simple reminder vs tracked habit
    var completionDates: [Date]     // When tracking enabled
    var skipDates: [Date]
    var category: String            // For organization
}
```

**Benefits:**
- ✅ Single concept: "Activities" (simple to understand)
- ✅ Flexible: Toggle tracking on/off without recreating
- ✅ Extensible: Easy to add icons, colors, categories
- ✅ Less code: ~40% reduction in model/service code
- ✅ Future-proof: Easy to add goals, routines, etc.

**New Services:**
- **ActivityService** replaces ReminderService (unified scheduling)
- AIService updated to inject tracked activities into context

**Note:** Backward compatibility code was removed in v1.0.6 as app was unreleased. All characters use the unified Activity model from the start.

### Architecture Improvements (Oct 27, 2025)
- **AppState refactoring**: Separated state management from app lifecycle
- **Multi-file storage**: Individual character files for scalability
- **Context update overhaul**: Background debounced updates (5 min/5 messages)
- **VoiceSessionManager extraction**: Reduced ChatViewModel by ~150 lines
- **WindowMoveObserver ViewModifier**: Reusable view logic

### Performance & Quality
- **Window position debouncing**: Fixed critical issue saving on every pixel drag (now 500ms debounce)
- **Error handling**: Replaced silent `try?` with explicit logging and error codes
- **Memory leaks fixed**: Retain cycles in VoiceService, ReminderService, AppDelegate
- **API key sanitization**: No longer exposed in debug logs
- **URLSession memory leak**: Reusable session with proper cleanup
- **Backup/recovery system**: Automatic backups before saves with corruption detection

### Testing & Code Quality
- Added 131 unit tests (89%+ pass rate)
- Zero force unwraps in production code
- Result types for error propagation
- Comprehensive documentation

For detailed version history, see `CHANGELOG.md`.

## Deployment

### Local Development
```bash
./scripts/deploy.sh                              # Build and install to /Applications
codesign -vv /Applications/WigiAI.app            # Verify code signing
codesign -d --entitlements - /Applications/WigiAI.app  # Check entitlements
```

### GitHub Releases (Automated)
```bash
./scripts/bump_version.sh patch "Bug fixes"      # Updates version, creates tag, and pushes
```

**What happens automatically:**
1. Script updates `MARKETING_VERSION` in Xcode project
2. Commits version bump
3. Creates annotated git tag (e.g., `v1.0.7`)
4. Pushes to GitHub
5. GitHub Actions workflow triggers:
   - Builds DMG with code signing
   - Creates GitHub release
   - Auto-generates `appcast.xml` from release metadata
   - Pushes appcast.xml back to main branch
6. Users receive auto-updates via Sparkle

**Key Points:**
- `MARKETING_VERSION` is the only version number that matters (user-facing)
- `CURRENT_PROJECT_VERSION` (build number) stays at "1" - not used
- `appcast.xml` is auto-generated from GitHub releases - don't edit manually
- Workflow: `.github/workflows/release.yml`

## Configuration

### Info.plist (Auto-Generated)
- `LSUIElement = YES` - Menubar-only app (no Dock icon)
- `NSUserNotificationsUsageDescription` - Notification permissions for activity reminders
- `NSMicrophoneUsageDescription` - Microphone access for voice-to-text conversation
- `NSSpeechRecognitionUsageDescription` - Speech recognition for voice input
- `NSSupportsAutomaticTermination = NO` - Keep app running in background
- `NSSupportsSuddenTermination = NO` - Prevent abrupt termination
- `SUFeedURL` - Sparkle appcast URL for auto-updates
- `SUPublicEDKey` - Sparkle public key for verifying update signatures
- `SUScheduledCheckInterval` - Auto-update check frequency (86400 = daily)

### Code Signing
- **Local dev:** Apple Development certificate (free Apple ID)
- **Distribution:** Apple Developer Program ($99/year) recommended
- **Entitlements:** App sandboxing disabled in `WigiAI.entitlements` (`com.apple.security.app-sandbox = false`)

### Logging & Error Handling

**LoggerService Architecture:**
- Category-based logging with emoji prefixes for visual scanning
- Categories: chat, ai, voice, storage, habits, reminders, sound, ui, app, updates
- Privacy-aware: User content truncated to 50 characters in logs
- API keys automatically sanitized (never logged)
- Example: `LoggerService.ai.info("🤖 Starting AI request...")`

**Error Handling Patterns:**
- `Result<T, Error>` types for storage operations
- Explicit error logging (no silent `try?` in production)
- Backup/recovery system: Automatic backups before file saves
- Corruption detection with fallback to backups
- User-facing alerts for critical errors (API key issues, storage failures)

**Security:**
- **KeychainService**: API keys stored in macOS Keychain (not in JSON or logs)
- Prevents accidental Git commits of secrets
- Automatic migration from legacy JSON storage

## Known Issues
- ⚠️ "Unable to open mach-O at path: default.metallib" warning - Harmless SwiftUI/Metal warning
- ℹ️ Running both /Applications and Xcode versions creates separate notification states

## Future Enhancements
- Whisper API for better STT accuracy
- Multi-language support
- Voice activity detection (hands-free mode)
- Character animations and mood expressions
- Character marketplace/sharing
- Multi-modal input (images, files)
- Cross-device sync (iCloud)
- iOS companion app (~70% code reusable)

## Documentation
- `README.md` - User-facing documentation and quick start
- `CHANGELOG.md` - Version history and release notes
- `CLAUDE.md` - This file (technical/developer documentation)
- `scripts/README.md` - Build and deployment script documentation
