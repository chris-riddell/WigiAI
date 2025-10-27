# WigiAI - AI Companion Desktop Widget

## Project Overview
A macOS native app featuring AI-powered character companions that live on your desktop, providing habit tracking through conversational check-ins and proactive notifications.

**Current Version:** 1.0.0 (MVP Complete - Oct 26, 2025)
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
- **Suggested replies** - AI-generated quick response buttons
- **Temperature control** - Adjustable creativity (0.0-2.0, default 0.7)

### Habit Tracking
- **Conversational tracking** - AI naturally asks about and tracks habits
- **Flexible scheduling** - Daily, weekdays, weekends, or custom days
- **Visual progress** - 7-day calendar with color-coded completion
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
├── Models/              Character, Message, Reminder, Habit, AppSettings, CharacterTemplate, AppState
├── Views/               CharacterWidget, ChatWindow, SettingsWindow, CharacterLibraryView
│   └── ViewModifiers/   WindowMoveObserver (reusable view logic)
├── Services/            AIService, StorageService, ReminderService, VoiceSessionManager
├── Utilities/           Strings (centralized localization)
├── CharacterTemplates/  10 pre-built character JSON templates (folder reference required)
└── Assets.xcassets/     App icons and menu bar icons
```

**IMPORTANT:** The `CharacterTemplates/` folder must be added to Xcode as a folder reference (blue folder).

### Testing
- **131 unit tests** across 5 test suites (89%+ pass rate)
- Coverage: HabitTests, CharacterTests, MessageTests, ReminderTests, CharacterTemplateTests
- Run tests: `xcodebuild test -scheme WigiAI -destination 'platform=macOS'`

### Data Models
- **AppState** - `@MainActor ObservableObject` centralized state container
- **Character** - name, masterPrompt, avatarAsset, position, reminders, habits, chatHistory, persistentContext, voiceSettings
- **Habit** - name, targetDescription, frequency, completionDates, skipDates, reminderTime
- **Message** - role, content, timestamp
- **Reminder** - time, reminderText, isEnabled, linkedHabitId
- **CharacterTemplate** - id, name, category, description, avatar, masterPrompt, habits[], reminders[]
- **AppSettings** - globalAPIConfig, characterIds (UUIDs only), voiceSettings, autoUpdateEnabled
- **APIConfig** - apiURL, apiKey, model, temperature, useStreaming

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

### Context Management Strategy
- **System prompt:** Character's master prompt (cached by OpenAI for 50% cost reduction)
- **Persistent context:** Auto-updated summary (bullet points, incremental merge)
- **Recent history:** Last 10 messages (configurable)
- **Background updates:** Debounced every 5 minutes OR 5 messages (not tied to window close)
- **Habit injection:** Separate from persistent context to preserve prompt cache

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

### Window Architecture
- **CharacterPanel**: Custom NSPanel (non-activating, stationary, draggable)
- **ChatPanel**: Custom NSPanel (activating, resizable, non-blocking close)
- **Position saving**: Debounced 500ms to prevent excessive disk writes

## Recent Major Changes (Oct 27, 2025)

### Architecture Improvements
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

### GitHub Releases
```bash
./scripts/bump_version.sh patch "Bug fixes"      # Tag version
git push origin main && git push origin --tags   # Push and trigger build
```
- GitHub Actions automatically builds DMG and generates appcast.xml
- Workflow: `.github/workflows/release.yml`
- Users receive auto-updates via Sparkle framework

## Configuration

### Info.plist (Auto-Generated)
- `LSUIElement = YES` - Menubar-only app
- `NSUserNotificationsUsageDescription` - Notification permissions
- `NSSpeechRecognitionUsageDescription` - Voice interaction
- `NSSupportsAutomaticTermination = NO` - Stay running
- `SUFeedURL` - Sparkle appcast URL for updates

### Code Signing
- **Local dev:** Apple Development certificate (free Apple ID)
- **Distribution:** Apple Developer Program ($99/year) recommended
- **Entitlements:** App sandboxing disabled (`com.apple.security.app-sandbox = false`)

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
