# WigiAI Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

## [1.0.6] - 2024-10-30

### Added

**🤖 Smart Model Switching**
- Auto-switch from gpt-4.1 to gpt-4.1-mini after 10 messages for cost savings (optional, default: enabled)
- Respects custom model settings (only applies when using global default)
- Configurable via toggle in Settings and Onboarding

**⚡ Quick-Add Activities**
- New "+" button in Habit Progress view to add activities without opening Settings
- Reuses ActivityEditorSheet component for consistency
- Streamlines workflow for habit tracking

**🧠 Enhanced AI Context**
- Shortened communication style prompt for punchier responses
- Enhanced persistent context prompt with 7 priority areas
- Better specificity guidance ("Exercise 3x/week" not "Exercise regularly")
- Includes temporal details and motivations for deeper understanding

### Changed

**📱 UI/UX Improvements**
- Fixed dark mode contrast for AI message bubbles (better visibility)
- Updated default model from gpt-4o to gpt-4.1
- All documentation updated to reference gpt-4.1

**🧹 Code Quality**
- Removed all backward compatibility code (~522 lines)
- Deleted ActivityMigration.swift (app unreleased, no migration needed)
- Zero deprecation warnings

## [1.0.5] - 2024-10-27

### Fixed
- Fixed microphone permission handling
- Fixed API rate limit issues with GitHub API requests
- Now uses authenticated requests to avoid rate limiting

## [1.1.0] - 2024-10-27

### Changed

**🗄️ Multi-File Storage Architecture**
- **BREAKING (with automatic migration):** Refactored from single-file to multi-file storage architecture
- Each character now stored in individual JSON file: `~/Library/Application Support/WigiAI/characters/{UUID}.json`
- Main settings file (`app_settings.json`) now stores only global configuration and character UUIDs
- Automatic one-time migration from old single-file format on first launch after upgrade
- Zero data loss during migration - all chat history, habits, and settings preserved

### Improved

**⚡ Performance Enhancements**
- Saving a character now only writes that character's file, not entire app state
- Significantly faster character updates, especially with large chat histories
- Reduced memory usage during save operations

**🛡️ Data Safety**
- File corruption now isolated to individual characters, not entire dataset
- Each character file is independently recoverable
- Atomic writes prevent partial data corruption

**🏗️ Architecture Improvements**
- AppDelegate maintains in-memory `characters` array for fast access
- StorageService provides granular persistence methods (`saveCharacter`, `loadCharacter`, `deleteCharacter`)
- Improved error handling with Result types for storage operations
- Better logging for troubleshooting storage issues

### Technical Details

- AppSettings model changed: `characters: [Character]` → `characterIds: [UUID]`
- All views updated to use new storage pattern via `appDelegate.characters`
- StorageService rewritten with multi-file support
- Migration logic automatically detects old format and converts to new structure
- Backward compatible decoder in AppSettings for seamless upgrades

## [1.0.0] - 2025-10-27

### Initial Release 🎉

**WigiAI** - AI-Powered Desktop Companions for macOS

#### Features

**💬 Conversational AI**
- Multiple character companions with unique personalities
- Real-time AI conversations with OpenAI-compatible APIs
- Streaming responses with live typing effect
- Suggested quick replies for faster interaction
- Persistent chat history and contextual memory
- Temperature control for response creativity (0.0-2.0)

**🎨 Character System**
- 4 avatar styles: Person, Professional, Scientist, Artist
- Customizable personality prompts per character
- Per-character model overrides
- Draggable desktop widgets with position persistence
- Multiple characters can be active simultaneously
- 10 pre-built character templates with habits and reminders

**🎯 Habit Tracking**
- Conversational AI integration - characters ask about habits naturally
- Visual 7-day calendar with color-coded progress
- Quick action buttons (Done ✓ / Skip →)
- Celebration animations with confetti for completions
- Streak tracking with milestone messages
- Flexible scheduling (daily, weekdays, weekends, custom)
- Optional per-habit reminder notifications
- Full completion/skip history

**⏰ Smart Reminders**
- Time-based check-in notifications
- Personalized reminder messages per character
- Visual badges on character widgets
- Automatic AI-triggered conversations

**🎤 Voice Interaction** (Experimental)
- Speech-to-Text using native macOS APIs (offline, zero cost)
- Text-to-Speech with 10 premium voices
- Push-to-talk and auto-submit modes
- Per-character voice settings
- Installation detection with download guidance

**⚙️ Advanced Features**
- Auto-updates via Sparkle framework
- Launch on startup option
- OpenAI, Ollama, and custom API support
- Secure local data storage
- No telemetry or analytics

#### Technical Details

- **Platform:** macOS 14.0 (Sonoma) or later
- **Language:** Swift 5.9+ with SwiftUI
- **Architecture:** Native macOS app with menubar interface
- **Storage:** Local JSON files in Application Support
- **Updates:** GitHub Releases with automatic update checking

---

**Full documentation:** See [README.md](README.md) and [CLAUDE.md](CLAUDE.md)
