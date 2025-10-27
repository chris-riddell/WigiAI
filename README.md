# WigiAI

<div align="center">

**AI-Powered Desktop Companions for macOS**

Your personal AI assistant that lives on your desktop. Build better habits through conversational tracking, enjoy natural AI conversations, and stay motivated with celebration animations - all from customizable character companions.

[Download Latest Release](https://github.com/chris-riddell/WigiAI/releases/latest) • [Report Bug](https://github.com/chris-riddell/WigiAI/issues) • [Request Feature](https://github.com/chris-riddell/WigiAI/issues)

</div>

---

## 💭 Why I Built This

I wanted an AI assistant that felt more like a companion than a tool. Existing AI apps either hide in browser tabs or lack the habit tracking features I needed. I kept forgetting to check my habit tracker, and my AI conversations felt disconnected from my actual goals.

WigiAI combines the best of both worlds:
- **Visible desktop widgets** so your AI is always present (not hidden away)
- **Conversational habit tracking** so you can just chat instead of clicking checkboxes
- **Persistent memory** so your AI remembers your context across all conversations
- **Privacy-first design** with offline voice features and local AI support (Ollama)

I built this for myself, but I'm sharing it in case it helps others too. If you have ideas to make it better, **pull requests are welcome!** 🙌

---

## 🌟 Features

### 💬 **Conversational AI Characters**
- Multiple character companions with unique personalities
- Real-time AI-powered conversations using OpenAI-compatible APIs
- Persistent chat history and contextual memory
- Suggested quick replies for faster interaction
- Model selection (GPT-4, GPT-4o-mini, or custom models)

### 🎨 **Fully Customizable Characters**
- **Create AI companions for anything!** Define custom personalities, habits, and reminders for any use case
- **10 ready-to-use templates** included (Fitness Coach, Study Buddy, Budget Tracker, etc.) - use as-is or customize
- **4 Avatar Styles:** Person 👤, Professional 💼, Scientist 👨‍🔬, Artist 🎨
- Custom personality prompts for each character
- Per-character model overrides
- Position memory (characters stay where you place them)
- Multiple characters can be active simultaneously

### 🎯 **Habit Tracking** (NEW)
- **Conversational AI Integration:** Characters naturally ask about and track habits
- **Visual Progress:** 7-day calendar with color-coded completion status
- **Quick Actions:** Instant "Done ✓" and "Skip →" buttons for pending habits
- **Celebration Animations:** Confetti and milestone messages for streak achievements
- **Flexible Scheduling:** Daily, weekdays, weekends, or custom day selection
- **Reminder Notifications:** Optional per-habit reminder times
- **Streak Tracking:** Automatic calculation with flame emoji 🔥
- **Full History:** Complete tracking of completions and skips
- **AI-Powered Parsing:** AI understands natural responses and marks habits automatically

### ⏰ **Smart Reminders**
- Time-based check-in notifications
- Personalized reminder messages
- Character badges when reminders are due
- Automatic AI-triggered conversations

### 🎤 **Voice Interaction** (Experimental)
- **Speech-to-Text:** Push-to-talk voice input using native macOS APIs
- **Text-to-Speech:** AI responses read aloud with premium voices
- **10 Premium Voices:** US, UK, and Australian English options
- Installation detection with one-click download
- Adjustable speech rate and per-character voice settings
- Completely offline (no API costs for voice features)

### ⚙️ **Advanced Settings**
- OpenAI-compatible API support (OpenAI, Ollama, local servers)
- Streaming responses toggle
- Temperature control (0.0-2.0) for response creativity
- Message history configuration
- Auto-updates with Sparkle framework
- Launch on startup option

---

## 📥 Installation

### Download Pre-built Release (Recommended)

1. **Download the latest release:**
   - Visit the [Releases page](https://github.com/chris-riddell/WigiAI/releases/latest)
   - Download `WigiAI-v1.0.0.dmg` (or latest version)

2. **Install the app:**
   - Open the downloaded DMG file
   - Drag WigiAI.app to your Applications folder
   - Eject the DMG

3. **Launch WigiAI:**
   - Open from Applications folder
   - Right-click → Open (first time only, to bypass Gatekeeper)
   - Allow microphone access if using voice features (optional)

### Build from Source

See [Development Setup](#-development) below.

---

## 🚀 Quick Start

### Initial Setup

1. **Launch WigiAI** - The app will appear in your menubar
2. **Configure API Settings:**
   - Click menubar icon → Settings
   - Enter your OpenAI API key (or compatible API URL)
   - Select your preferred model (default: gpt-4o)

3. **Create Your First Character:**
   - Settings → Characters → Add Character
   - Choose an avatar style
   - Set a name and personality prompt
   - Click Save

4. **Start Chatting:**
   - Click on your character's widget on the desktop
   - Type a message or use the microphone button (if voice enabled)
   - Your character will respond with AI-powered conversations

### Setting Up Habits

1. **Open Character Settings:**
   - Menubar → Settings → Characters → Select character
   - Scroll to "Habits" section

2. **Add a Habit:**
   - Click "Add Habit" button
   - Enter habit name (e.g., "Morning Exercise")
   - Set target description (e.g., "30 minutes of cardio")
   - Choose frequency:
     - **Daily:** Every day
     - **Weekdays:** Monday-Friday
     - **Weekends:** Saturday-Sunday
     - **Custom:** Select specific days
   - Optionally set a reminder time
   - Click "Save"

3. **Track Progress:**
   - **AI Conversations:** Character will naturally ask about your habit
   - **Quick Actions:** Use "Done ✓" or "Skip →" buttons in chat window
   - **Visual Progress:** Click progress button in chat header to see 7-day calendar
   - **Celebrations:** Enjoy confetti animations on completions!
   - **Natural Language:** Just say "I did it!" and AI will mark it complete

### Voice Features (Optional)

1. **Enable Voice in Settings:**
   - Settings → General → Voice Interaction
   - Toggle "Enable Voice Features"
   - Choose which features to enable (STT/TTS)

2. **Download Premium Voices:**
   - Settings → General → Voice section
   - Select a premium voice from the dropdown
   - If not installed, click "Open System Settings"
   - Download your preferred voice (free from Apple)

3. **Use Voice in Chat:**
   - **Push-to-Talk:** Hold microphone button while speaking
   - **Auto-Read:** Enable TTS to hear AI responses
   - **Mute/Unmute:** Click speaker icon to toggle voice responses

---

## 🎨 Character Customization

**Create AI companions for any purpose!** Characters are completely customizable - define unique personalities, habits, and reminders to fit your exact needs.

### Master Prompts

The master prompt defines your character's personality. Here are some examples:

**Personal Coach:**
```
You are an encouraging personal coach who helps users build healthy habits.
Be supportive, motivational, and celebrate their progress. Use positive
language and ask thoughtful questions about their goals.
```

**Professional Assistant:**
```
You are a professional executive assistant. Be concise, organized, and
help manage tasks efficiently. Focus on productivity and time management.
```

**Creative Companion:**
```
You are a creative and imaginative companion who loves brainstorming ideas.
Be playful, curious, and encourage creative thinking. Ask "what if" questions.
```

### Per-Character Model Override

You can assign different AI models to different characters:
- **Main character:** gpt-4o (recommended, high-quality responses)
- **Budget-conscious assistant:** gpt-4o-mini (faster, cost-effective)
- **Custom character:** Any OpenAI-compatible model

### Pre-Built Character Templates

**Characters are totally customizable** - create an AI companion for anything! To get you started, WigiAI includes 10 pre-made templates you can use as-is or customize:

- **Executive Assistant** (Productivity) - Task management, email reminders, daily planning
- **Fitness Coach** (Health) - Workout tracking, nutrition guidance, motivation
- **Sleep Optimizer** (Health) - Sleep schedule, bedtime routine, quality tracking
- **Study Buddy** (Learning) - Study sessions, flashcards, practice problems
- **Writing Coach** (Creative) - Morning pages, writing sessions, editing time
- **Mindfulness Guide** (Health) - Meditation, gratitude practice, breathing exercises
- **Budget Tracker** (Finance) - Expense logging, budget reviews, no-spend days
- **Meal Prep Partner** (Lifestyle) - Meal planning, grocery shopping, prep sessions
- **Focus Guardian** (Productivity) - Pomodoro technique, deep work blocks, distraction management
- **Habit Builder** (Lifestyle) - General habit formation, streak tracking, weekly reviews

Each template comes with:
- Pre-configured personality and master prompt
- Relevant habits with suggested schedules
- Optional reminder times
- Category-based organization for easy browsing

Browse the character library in-app to add any template with one click!

---

## ⚙️ Configuration

### API Settings

**OpenAI:**
```
API URL: https://api.openai.com/v1
API Key: sk-...
Model: gpt-4o
```

**Ollama (Local):**
```
API URL: http://localhost:11434/v1
API Key: (leave blank or use "ollama")
Model: llama2
```

**Custom API:**
```
API URL: https://your-api-endpoint.com/v1
API Key: your-api-key
Model: your-model-name
```

### Advanced Settings

- **Temperature:** 0.0-2.0 (default: 0.7)
  - Lower = more focused and deterministic
  - Higher = more creative and varied

- **Message History:** Number of recent messages sent to API (default: 10)
  - More messages = better context, higher token usage
  - Fewer messages = lower cost, less context

- **Streaming:** Toggle real-time response streaming
  - Enable for live typing effect
  - Disable for slower connections

---

## 🎯 Habit Tracking System

### How It Works

**Conversational AI Integration:**
- Characters naturally ask about your habits during conversations
- AI understands responses like "Yes, I did it!" or "Not today"
- Structured markers: `[HABIT_COMPLETE: uuid]` or `[HABIT_SKIP: uuid]`
- Markers are automatically stripped from displayed messages
- Habit context injected into AI system prompt (no cache invalidation)

**Visual Tracking:**
- **7-Day Calendar:** Color-coded squares showing last week's progress
  - 🟢 Green = Completed
  - 🔴 Red = Skipped
  - ⚪ Gray border = Pending/Due
  - Transparent = Not due that day
- **Streak Counter:** Consecutive completions with flame emoji 🔥
- **Progress Percentage:** Overall completion rate

**Quick Actions:**
- Pending habits appear above message input
- "Done ✓" button marks complete and triggers celebration
- "Skip →" button marks skipped (no broken streak penalty)
- Auto-hides when no pending habits

### Habit Frequencies

- **Daily:** Every day (7 days/week)
- **Weekdays:** Monday through Friday (5 days/week)
- **Weekends:** Saturday and Sunday (2 days/week)
- **Custom:** Select any combination of specific days

### Milestone Celebrations

Confetti animation with milestone messages:
- **1 Day:** "Great start! 🌟"
- **3 Days:** "Three in a row! 🎯"
- **7 Days:** "One week strong! 💪"
- **14 Days:** "Two weeks - amazing! 🔥"
- **30 Days:** "One month milestone! 🏆"
- **100 Days:** "Century club! Incredible! 🌈"
- **Every 50 Days:** "{streak} days - unstoppable! 🚀"

**Celebration Features:**
- 50 colorful confetti pieces with falling animation
- Success icon (green gradient circle with checkmark)
- Streak count display
- Sound effects (regular + milestone-specific sounds)
- Auto-dismiss after 2.5 seconds

### Example Conversation

```
Character: "Good morning! Did you get your morning exercise in?"

You: "Yes, I did 30 minutes on the treadmill!"

[AI marks habit complete]
[🎉 Confetti animation appears]
[Shows: "7 day streak! 💪 One week strong!"]

Character: "That's amazing! You've kept it up for a whole week! 🔥"
```

---

## 🎤 Voice Features Guide

### Premium Voices

**US English (6 voices):**
- Ava, Evan, Joelle, Nathan, Noel, Zoe

**UK English (3 voices):**
- Fiona (Scottish), Malcolm, Stephanie

**Australian English (1 voice):**
- Matilda

### Installing Voices

**macOS 14 and earlier:**
1. System Settings → Accessibility → Spoken Content
2. Click info button next to System Voice
3. Select English variant
4. Click download button next to voice name

**macOS 15 (Sequoia) and later:**
1. Open VoiceOver Utility (Fn + F8)
2. Click Speech in sidebar
3. Select voice from dropdown
4. Voice will download automatically

### Voice Features

- **Speech-to-Text:** Completely offline, no API costs
- **Text-to-Speech:** Uses native macOS voices (offline)
- **Auto-Submit:** Voice input automatically sends (toggle in settings)
- **Per-Character Voices:** Assign different voices to each character

---

## 🔒 Privacy & Security

### Data Storage

- **All data stored locally** in `~/Library/Application Support/WigiAI/`
- **No telemetry or analytics** - your conversations stay private
- **API key stored securely** in app's sandboxed storage
- **Chat history never leaves your Mac** (except API calls to your configured endpoint)

### Permissions

- **Microphone:** Required for voice input (optional feature)
- **Speech Recognition:** Required for speech-to-text (optional feature)
- **Notifications:** For habit reminders (recommended)

---

## 💻 Development

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Swift 5.9 or later

### Build Instructions

1. **Clone the repository:**
   ```bash
   git clone https://github.com/chris-riddell/WigiAI.git
   cd WigiAI
   ```

2. **Open in Xcode:**
   ```bash
   open WigiAI.xcodeproj
   ```

3. **Build and run:**
   - Select WigiAI scheme
   - Product → Run (⌘R)

### Project Structure

```
WigiAI/
├── WigiAI/
│   ├── WigiAIApp.swift              # Main app entry point
│   ├── AppDelegate.swift            # App lifecycle and menubar
│   ├── Models/                      # Data models
│   │   ├── AppSettings.swift        # App configuration
│   │   ├── Character.swift          # Character data model
│   │   ├── Habit.swift              # Habit tracking model (NEW)
│   │   ├── HabitFrequency.swift     # Habit frequency enum (NEW)
│   │   ├── Message.swift            # Chat message model
│   │   └── Reminder.swift           # Reminder model
│   ├── Services/                    # Core services
│   │   ├── AIService.swift          # OpenAI API + habit parsing
│   │   ├── StorageService.swift     # JSON persistence
│   │   ├── ReminderService.swift    # Notifications + habit reminders
│   │   ├── SoundEffects.swift       # Sound effects + celebrations
│   │   ├── VoiceService.swift       # Speech-to-text & TTS
│   │   └── UpdateService.swift      # Auto-update system
│   └── Views/                       # SwiftUI views
│       ├── CharacterWidget.swift    # Desktop character widget
│       ├── ChatWindow.swift         # Chat + quick actions + celebrations
│       ├── SettingsWindow.swift     # Settings + habit editor
│       ├── HabitProgressView.swift  # 7-day calendar widget (NEW)
│       ├── HabitQuickActions.swift  # Quick action buttons (NEW)
│       └── CelebrationView.swift    # Confetti animation (NEW)
├── scripts/                         # Build and deployment scripts
├── CLAUDE.md                        # Detailed project documentation
└── README.md                        # This file
```

### Deployment Scripts

**Local Deployment:**
```bash
./scripts/deploy.sh
```
Builds and installs WigiAI to `/Applications/`

**Version Bump & Release:**
```bash
./scripts/bump_version.sh [major|minor|patch] "Release description"
git push origin main && git push origin --tags
```
Creates a version tag and triggers GitHub Actions release build

**Documentation:**
- [DEPLOYMENT.md](DEPLOYMENT.md) - Local deployment guide
- [GITHUB_RELEASE.md](GITHUB_RELEASE.md) - GitHub Actions automation
- [AUTO_UPDATE.md](AUTO_UPDATE.md) - Auto-update configuration
- [CLAUDE.md](CLAUDE.md) - Complete project documentation
- [CHANGELOG.md](CHANGELOG.md) - Version history

### Contributing

**Contributions from the community are very welcome!** 🙌

Whether you want to:
- Fix a bug you found
- Add a feature you wish existed
- Improve documentation
- Create new character templates
- Enhance the UI/UX

**I'm open to pull requests!** Here's how to contribute:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request with a clear description of your changes

**Areas where PRs would be especially appreciated:**
- Additional character templates with creative use cases
- UI/UX improvements and animations
- Better habit tracking visualizations
- Performance optimizations
- Bug fixes and error handling
- Documentation improvements

Don't hesitate to open an issue first if you want to discuss a larger change!

---

## 📋 Troubleshooting

### Voice Features Not Working

**"No" appearing in text box:**
- Check microphone permissions in System Settings
- Ensure Speech Recognition is enabled
- Try restarting the app

**Voice not transcribing:**
- Speak clearly and at normal volume
- Check Console.app for logs (search for "🎤")
- Verify microphone is not muted in System Settings

**TTS not speaking:**
- Verify voice is installed (see Voice Features Guide)
- Check speaker/mute button in chat window
- Ensure TTS is enabled in Settings

### API Connection Issues

**"Invalid API key" error:**
- Verify API key is correct in Settings
- Check API URL format (should end with `/v1`)
- For Ollama, ensure server is running (`ollama serve`)

**Streaming not working:**
- Try disabling streaming in Settings
- Check network connection
- Verify API endpoint supports streaming

### Character Widget Issues

**Widget not appearing:**
- Check if character is enabled in Settings
- Try restarting the app
- Verify widget is not off-screen (drag from edge)

**Position not saving:**
- Wait a moment after moving widget
- Ensure app has write permissions to Application Support folder

---

## 🗺️ Roadmap

### Recently Completed ✅

- [x] **Habit Tracking System** - Complete 8-phase implementation
  - Conversational AI integration
  - Visual 7-day calendar progress
  - Quick action buttons
  - Celebration animations with confetti
  - Reminder notifications
  - Streak tracking and milestones

### Planned Features

- [ ] **Habit Analytics:** Progress charts and completion trends over time
- [ ] **Apple Health Integration:** Sync habits with Health app data
- [ ] **Multi-modal Input:** Image and file sharing in conversations
- [ ] **iCloud Sync:** Sync characters and chat history across devices
- [ ] **iOS Companion App:** Mobile version for on-the-go check-ins (70% code reusable)
- [ ] **Character Marketplace:** Share and download community characters
- [ ] **Advanced Animations:** More lifelike character movements
- [ ] **Mood-based Expressions:** Visual feedback based on conversation tone
- [ ] **Background Activity Monitoring:** Respond to user activity/idle time
- [ ] **Advanced Voice Features:**
  - Whisper API integration for better transcription
  - Voice activity detection (hands-free)
  - Multi-language support
- [ ] **Enhanced Context System:** AI-powered context summarization

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **OpenAI** - For the GPT API that powers conversations
- **Apple** - For excellent native speech APIs (SFSpeechRecognizer, AVSpeechSynthesizer)
- **Sparkle** - For the auto-update framework

---

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/chris-riddell/WigiAI/issues)
- **Discussions:** [GitHub Discussions](https://github.com/chris-riddell/WigiAI/discussions)

---

<div align="center">

**Made with ❤️ for the macOS community**

[⬆ Back to Top](#wigiai)

</div>
