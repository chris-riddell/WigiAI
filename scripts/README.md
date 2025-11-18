# WigiAI Scripts

Automation scripts for building, deploying, and managing WigiAI.

## 📜 Scripts

### `deploy.sh`

One-command deployment to your local Applications folder.

**Usage:**
```bash
./scripts/deploy.sh
```

**What it does:**
1. Stops any running WigiAI instance
2. Builds the app in Release mode (optimized)
3. Copies it to /Applications
4. Asks if you want to launch it
5. Optionally cleans up build artifacts

**Perfect for:**
- Testing production builds locally
- Installing updates after making changes
- Quick development iteration

---

### `bump_version.sh`

Bump version and prepare for GitHub release.

**Usage:**
```bash
# Patch version (1.0.0 → 1.0.1)
./scripts/bump_version.sh patch "Bug fixes"

# Minor version (1.0.0 → 1.1.0)
./scripts/bump_version.sh minor "New features"

# Major version (1.0.0 → 2.0.0)
./scripts/bump_version.sh major "Breaking changes"
```

**What it does:**
1. Updates version in Xcode project
2. Commits the version change
3. Creates a git tag (e.g., `v1.0.1`)
4. Shows you the push commands

**Then push to trigger GitHub release:**
```bash
git push origin main
git push origin --tags
```

GitHub Actions will automatically build, sign, notarize, and create the release.

---

### `create_dmg.sh`

Creates a DMG disk image for distribution.

**Usage:**
```bash
./scripts/create_dmg.sh <path-to-app> <output-name.dmg>
```

**Example:**
```bash
# Build the app first
./scripts/deploy.sh

# Create DMG
./scripts/create_dmg.sh /Applications/WigiAI.app WigiAI-1.0.0.dmg
```

**What it does:**
1. Validates the app exists
2. Creates a temporary DMG structure
3. Includes Applications folder symlink
4. Adds README with installation instructions
5. Creates compressed DMG with zlib compression

**Perfect for:**
- Local testing of DMG creation
- Manual distribution (before GitHub setup)
- Custom release packages

---

### `generate_icon.swift`

Generates all required app icon sizes from an SF Symbol.

**Usage:**
```bash
swift scripts/generate_icon.swift
```

**What it does:**
1. Creates icons from `character.bubble.fill` SF Symbol
2. Applies blue-to-purple gradient background
3. Generates all macOS icon sizes (16x16 to 1024x1024)
4. Saves to `WigiAI/Assets.xcassets/AppIcon.appiconset/`

**Customize:**
Edit the script to change:
- Symbol name
- Gradient colors
- Icon style

**Then redeploy:**
```bash
swift scripts/generate_icon.swift
./scripts/deploy.sh
```

---

## 🚀 Quick Commands

```bash
# Build and install to Applications
./scripts/deploy.sh

# Create a new release
./scripts/bump_version.sh patch "Release description"
git push origin main && git push origin --tags

# Regenerate app icons after design changes
swift scripts/generate_icon.swift && ./scripts/deploy.sh

# Create DMG for manual distribution
./scripts/create_dmg.sh /Applications/WigiAI.app WigiAI.dmg

# Launch the installed app
open /Applications/WigiAI.app

# View app logs (if needed)
log show --predicate 'process == "WigiAI"' --last 1h
```

---

## 📦 Deployment Workflows

### Local Development
```bash
# Make code changes...
./scripts/deploy.sh
```

### GitHub Release
```bash
# Make code changes...
git add .
git commit -m "Add new feature"
./scripts/bump_version.sh minor "Added voice integration"
git push origin main
git push origin --tags
# GitHub Actions builds and creates release automatically
```

### Manual Distribution (no GitHub)
```bash
./scripts/deploy.sh
./scripts/create_dmg.sh /Applications/WigiAI.app WigiAI-1.0.0.dmg
# Share WigiAI-1.0.0.dmg with users
```

---

## 💡 Tips

- **Development vs Release:** When running from Xcode, you're using Debug mode. Use `deploy.sh` to test the optimized Release build.
- **Data persistence:** Your settings and chat history are stored in `~/Library/Application Support/WigiAI/` and won't be affected by redeploying.
- **Clean builds:** If you encounter issues, delete the `build/` directory before running `deploy.sh`.
- **Version format:** Always use semantic versioning: `MAJOR.MINOR.PATCH`

---

## 🔧 Troubleshooting

**"xcpretty: command not found"**
- Optional dependency for prettier build output
- Install with: `gem install xcpretty`
- Or ignore - the script falls back to standard xcodebuild output

**"App can't be opened"**
- Run: `xattr -cr /Applications/WigiAI.app`
- This removes quarantine attributes

**Build fails**
- Check Xcode can build successfully
- Verify Info.plist exists at `WigiAI/Info.plist`
- Try opening the project in Xcode and building manually first

**agvtool version commands fail**
- Open project in Xcode
- Build Settings → Versioning System → "Apple Generic"
- Build Settings → Current Project Version → "1"

---

## 📚 Documentation

- [CLAUDE.md](../CLAUDE.md) - Project documentation
- [README.md](../README.md) - User-facing documentation and quick start
