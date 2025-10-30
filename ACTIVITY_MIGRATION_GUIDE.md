# Activity Migration Completion Guide

## ✅ Completed (Build Passing)

### Core Architecture
- [x] **Activity.swift** - Unified model combining Reminder + Habit
- [x] **ActivityMigration.swift** - Automatic migration from legacy data
- [x] **Character.swift** - Now uses `activities: [Activity]` array
  - Legacy `reminders` and `habits` kept for backward compatibility during decoding
  - Automatic migration on first load of old character files
- [x] **ActivityService.swift** - Unified notification scheduling service
  - Replaces ReminderService with cleaner API
  - Handles both simple reminders and tracked habits
- [x] **AIService.swift** - Updated to use tracked activities
  - Filters `character.activities.filter { $0.isTrackingEnabled }`
  - Injects habit tracking context into AI prompts

### Build Status
✅ **Build succeeds** - Core functionality is operational
⚠️ **Deprecation warnings** - Old code still references `reminders`/`habits` (non-breaking)

---

## 🚧 Remaining Work

### 1. Update View Layer (UI)

#### High Priority
**ChatViewModel.swift** (~10 occurrences)
```swift
// OLD:
character.habits.firstIndex(where: { $0.id == habitId })
character.pendingReminder

// NEW:
character.activities.firstIndex(where: { $0.id == activityId && $0.isTrackingEnabled })
character.pendingActivityId // Look up activity by ID
```

**SettingsWindow.swift** (~15+ occurrences)
- Replace habit/reminder management UI
- Use single "Activities" section instead of separate tabs
- Filter by `activity.isTrackingEnabled` to show tracking UI

**HabitProgressView.swift** (~5 occurrences)
```swift
// OLD:
ForEach(character.habits) { habit in

// NEW:
ForEach(character.activities.filter { $0.isTrackingEnabled }) { activity in
```

**HabitQuickActions.swift** (~3 occurrences)
- Update to use Activity model
- Same tracking actions, just different model

**ChatHeaderView.swift** (~2 occurrences)
- Show pending activity count instead of habits

**CharacterLibraryView.swift** (~5 occurrences)
- Template creation uses activities array

#### Medium Priority
**AppDelegate.swift**
- Replace `ReminderService.shared` → `ActivityService.shared`
- Update notification handling to use `activityId` from userInfo

**ChatWindow.swift**
- Update pending reminder handling to use `pendingActivityId`

---

### 2. Update Tests

**CharacterTests.swift**
- Update test fixtures to use `activities` instead of `reminders`/`habits`
- Test activity migration logic

**AIServiceTests.swift**
- Update mocks to use tracked activities

**StorageServiceTests.swift**
- Test character save/load with activities

**CharacterTemplateTests.swift**
- Update template tests for activities

---

### 3. Update Character Templates

**CharacterTemplates/*.json** (10 files)
- Replace `reminders` and `habits` arrays with single `activities` array

Example transformation:
```json
{
  "reminders": [
    { "time": "09:00", "text": "Morning check-in" }
  ],
  "habits": [
    { "name": "Exercise", "targetDescription": "30 mins", "frequency": "daily" }
  ]
}
```

Becomes:
```json
{
  "activities": [
    {
      "name": "Morning check-in",
      "scheduledTime": "09:00",
      "isTrackingEnabled": false
    },
    {
      "name": "Exercise",
      "description": "30 mins",
      "frequency": "daily",
      "isTrackingEnabled": true
    }
  ]
}
```

---

### 4. Cleanup (Optional - Can Wait)

#### Remove Deprecated Models
Once all code is migrated:
- Delete `Reminder.swift`
- Delete `Habit.swift`
- Delete `HabitFrequency.swift` (merged into Activity.swift)
- Delete `ReminderService.swift`
- Remove deprecated properties from `Character.swift`

---

## 📋 Quick Migration Checklist

```bash
# 1. Find all remaining references
grep -r "\.habits\|\.reminders\|pendingReminder" WigiAI --include="*.swift" | grep -v "build/"

# 2. Update each file:
# - Replace `character.habits` → `character.activities.filter { $0.isTrackingEnabled }`
# - Replace `character.reminders` → `character.activities.filter { !$0.isTrackingEnabled || $0.scheduledTime != nil }`
# - Replace `habit.id` → `activity.id`
# - Replace `habit.name` → `activity.name`
# - Replace `habit.targetDescription` → `activity.description`
# - Replace `pendingReminder` → `pendingActivityId`

# 3. Build and fix errors
xcodebuild -scheme WigiAI build

# 4. Run tests
xcodebuild -scheme WigiAI test

# 5. Test migration with real data
# - Back up ~/Library/Application Support/WigiAI
# - Run app
# - Check logs for "Auto-migrated character"
# - Verify activities work correctly
```

---

## 🎯 Benefits After Complete Migration

### For Users
- **Simpler mental model**: "Activities" instead of separate Reminders/Habits
- **More flexible**: Toggle tracking on/off for any scheduled item
- **Cleaner UI**: Single activities list, less confusing

### For Development
- **Less code**: ~40% reduction in model/service code
- **Easier to extend**: Add features (icons, colors, categories) in one place
- **Better testing**: Single code path to test
- **Future-proof**: Easy to add new activity types (goals, routines, etc.)

---

## 🐛 Known Issues

1. **Deprecation warnings**: Non-breaking, will resolve after UI migration
2. **Template files**: Still use old format, need manual update
3. **Tests**: May fail until updated to use activities

---

## 💡 Tips

- **Use Find & Replace carefully**: Test after each file update
- **Keep legacy decode logic**: Ensures old user data migrates smoothly
- **Test with old character files**: Verify migration doesn't lose data
- **Update incrementally**: One file at a time, build after each

---

## 📞 Questions?

- Check `Activity.swift` for all available properties
- Check `ActivityMigration.swift` for migration logic
- Check `ActivityService.swift` for scheduling API
