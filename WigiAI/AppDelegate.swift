//
//  AppDelegate.swift
//  WigiAI
//
//  AI Companion Desktop Widget
//

import SwiftUI
import AppKit
import UserNotifications

// MARK: - Custom Panel for Character Widgets

class CharacterPanel: NSPanel {
    var characterId: UUID?
    var appDelegate: AppDelegate?

    override var canBecomeKey: Bool {
        return false  // Don't become key window
    }

    override var canBecomeMain: Bool {
        return false  // Don't become main window
    }
}

// MARK: - Custom Panel for Chat Windows

class ChatPanel: NSPanel {
    var characterId: UUID?
    var onClose: (() -> Void)?

    override var canBecomeKey: Bool {
        return true  // Chat windows can become key for text input
    }

    override var canBecomeMain: Bool {
        return true  // Chat windows can become main
    }

    override func close() {
        LoggerService.app.debug("🚪 ChatPanel close() called for character: \(self.characterId?.uuidString ?? "unknown")")
        onClose?()
        super.close()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate, @unchecked Sendable {
    var statusItem: NSStatusItem?

    /// Application state container
    ///
    /// **Thread Safety:** Initialized in `applicationDidFinishLaunching` which is guaranteed
    /// to run on the main thread before any other methods. AppState requires main actor
    /// for initialization due to `@MainActor` annotation.
    ///
    /// **Safety Note:** This is an intentional implicitly unwrapped optional because:
    /// - `applicationDidFinishLaunching` is called by the system before any other methods
    /// - AppState initialization requires main actor context
    /// - The app cannot function without AppState being initialized
    /// - All methods that access appState are guaranteed to run after initialization
    private(set) var appState: AppState!

    var characterWindows: [UUID: NSWindow] = [:]
    var chatWindows: [UUID: ChatPanel] = [:]  // Changed to ChatPanel for delegate access
    var settingsWindow: NSWindow?
    var charactersWindow: NSWindow?
    var onboardingWindow: NSWindow?
    private var isInitialLaunch = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure app as accessory (menubar only, no dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Initialize ReminderService to request notification permissions
        // This must happen early, before checking if there are characters
        _ = ReminderService.shared

        // Initialize AppState (requires main actor context)
        appState = AppState()

        LoggerService.app.debug("🚀 App launching - loaded \(self.appState.characters.count) characters")
        for character in appState.characters {
            LoggerService.app.debug("   📍 '\(character.name)' position: \(NSStringFromPoint(character.position))")
        }

        // Fix any off-screen widgets
        appState.validateCharacterPositions()

        // Setup menubar
        setupMenuBar()

        // Check if onboarding is needed
        if !appState.settings.hasCompletedOnboarding {
            showOnboarding()
        } else {
            // Create widgets for existing characters
            for character in appState.characters {
                LoggerService.ui.debug("🎨 Creating widget for '\(character.name)' at position: \(NSStringFromPoint(character.position))")
                createCharacterWidget(for: character)
                // Schedule reminders for each character
                ReminderService.shared.scheduleReminders(for: character)
            }
            LoggerService.app.info("✅ All widgets created")
        }

        // Clear initial launch flag after a delay
        // This prevents notifications from showing immediately on startup
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.isInitialLaunch = false
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't terminate when windows close - we're a menubar app
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Save all widget positions before exiting
        LoggerService.app.debug("💾 Saving widget positions before exit...")
        for (id, window) in characterWindows {
            if let characterPanel = window as? CharacterPanel {
                let position = characterPanel.frame.origin
                appState.updateCharacterPosition(id: id, position: position)
                LoggerService.app.debug("📍 Saved position for character: \(id)")
            }
        }
        LoggerService.app.info("✅ All widget positions saved")
    }

    // MARK: - Menu Bar Setup

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Try to load custom menubar icon, fall back to programmatic icon
            if let customIcon = NSImage(named: "MenuBarIcon") {
                button.image = customIcon
            } else {
                // Create a simple programmatic icon as fallback
                button.image = createMenuBarIcon()
            }
        }

        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Characters", action: #selector(openCharacters), keyEquivalent: "1"))
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Exit", action: #selector(exitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    // MARK: - Menubar Icon Creation

    func createMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()

        // Draw a simple character bubble icon
        let path = NSBezierPath()

        // Main circle (character head)
        let circle = NSBezierPath(ovalIn: NSRect(x: 4, y: 6, width: 10, height: 10))

        // Speech bubble tail
        path.move(to: NSPoint(x: 9, y: 6))
        path.line(to: NSPoint(x: 7, y: 3))
        path.line(to: NSPoint(x: 11, y: 6))
        path.close()

        // Fill with black (will be template, so macOS handles light/dark mode)
        NSColor.black.setFill()
        circle.fill()
        path.fill()

        image.unlockFocus()
        image.isTemplate = true  // Makes it adapt to light/dark mode

        return image
    }

    @objc func openSettings() {
        // Activate the app to bring windows to front (required for accessory apps)
        NSApp.activate(ignoringOtherApps: true)

        // If settings window already exists and is visible, bring it to front
        if let existingWindow = settingsWindow, existingWindow.isVisible {
            LoggerService.app.debug("⚙️ Settings window exists and visible, bringing to front")
            existingWindow.orderOut(nil) // Hide it first
            existingWindow.makeKeyAndOrderFront(nil) // Then show and focus
            return
        }

        // Window exists but isn't visible - recreate it
        if settingsWindow != nil {
            LoggerService.app.debug("⚙️ Settings window exists but not visible, recreating")
            settingsWindow = nil
        }

        // Create new settings window (API + General only)
        let settingsView = AppSettingsWindow(appDelegate: self, appState: appState)
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()

        // Set minimum and content size
        window.minSize = NSSize(width: 600, height: 500)
        window.contentMinSize = NSSize(width: 600, height: 500)
        window.setContentSize(NSSize(width: 600, height: 500))

        // Custom titlebar style - unified toolbar look
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.toolbar = NSToolbar()
        window.toolbar?.displayMode = .iconOnly
        window.toolbarStyle = .unified

        // Prevent window from releasing when closed - keep it alive
        window.isReleasedWhenClosed = false

        // Make panel not activate the app in menu bar
        window.isFloatingPanel = false
        window.becomesKeyOnlyIfNeeded = true
        window.hidesOnDeactivate = false

        // Prevent this window from showing app in menu bar
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        // Keep strong reference to prevent app termination
        settingsWindow = window

        // Show the window without activating the app in menu bar
        window.makeKeyAndOrderFront(nil)
    }

    @objc func openCharacters() {
        openCharacters(selectedCharacter: nil)
    }

    func openCharacters(selectedCharacter: UUID? = nil) {
        // Activate the app to bring windows to front (required for accessory apps)
        NSApp.activate(ignoringOtherApps: true)

        // If characters window already exists and is visible, bring it to front
        if let existingWindow = charactersWindow, existingWindow.isVisible {
            LoggerService.app.debug("👥 Characters window exists and visible, bringing to front")
            existingWindow.orderOut(nil) // Hide it first
            existingWindow.makeKeyAndOrderFront(nil) // Then show and focus
            return
        }

        // Window exists but isn't visible - recreate it
        if charactersWindow != nil {
            LoggerService.app.debug("👥 Characters window exists but not visible, recreating")
            charactersWindow = nil
        }

        // Create new characters window with optional selected character
        let charactersView = CharactersWindow(appDelegate: self, appState: appState, selectedCharacterID: selectedCharacter)
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Characters"
        window.contentView = NSHostingView(rootView: charactersView)
        window.center()

        // Set minimum and content size
        window.minSize = NSSize(width: 700, height: 600)
        window.contentMinSize = NSSize(width: 700, height: 600)
        window.setContentSize(NSSize(width: 700, height: 600))

        // Custom titlebar style - unified toolbar look
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.toolbar = NSToolbar()
        window.toolbar?.displayMode = .iconOnly
        window.toolbarStyle = .unified

        // Prevent window from releasing when closed - keep it alive
        window.isReleasedWhenClosed = false

        // Make panel not activate the app in menu bar
        window.isFloatingPanel = false
        window.becomesKeyOnlyIfNeeded = true
        window.hidesOnDeactivate = false

        // Prevent this window from showing app in menu bar
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        // Keep strong reference to prevent app termination
        charactersWindow = window

        // Show the window without activating the app in menu bar
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Onboarding

    func showOnboarding() {
        let onboardingView = OnboardingView(appDelegate: self, appState: appState, isPresented: Binding(
            get: { self.onboardingWindow != nil },
            set: { [weak self] isPresented in
                if !isPresented {
                    self?.onboardingWindow?.close()
                    self?.onboardingWindow = nil

                    // Create widgets for any existing characters after onboarding
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        for character in self.appState.characters {
                            self.createCharacterWidget(for: character)
                            ReminderService.shared.scheduleReminders(for: character)
                        }
                    }
                }
            }
        ))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 750),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to WigiAI"
        window.contentView = NSHostingView(rootView: onboardingView)
        window.center()
        window.isReleasedWhenClosed = false

        // Set minimum size but allow resizing if needed
        window.minSize = NSSize(width: 700, height: 750)

        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func exitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Character Widget Management

    /// Calculate a smart position for a new character widget (delegates to AppState)
    @MainActor
    func calculateSmartPosition() -> CGPoint {
        appState.calculateSmartPosition()
    }

    func createCharacterWidget(for character: Character) {
        let widgetView = CharacterWidget(characterId: character.id, appDelegate: self)

        let requestedRect = NSRect(x: character.position.x, y: character.position.y, width: 140, height: 170)
        LoggerService.app.debug("   📐 Requested rect: \(NSStringFromRect(requestedRect))")

        let window = CharacterPanel(
            contentRect: requestedRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Set character ID and app delegate for position tracking
        window.characterId = character.id
        window.appDelegate = self

        window.contentView = NSHostingView(rootView: widgetView)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .normal  // Changed from .floating to .normal so it doesn't stay on top
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .transient]
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true  // Enable hover tracking
        window.isMovableByWindowBackground = true  // Enable window dragging
        window.hasShadow = false
        window.titlebarAppearsTransparent = true
        window.isFloatingPanel = false
        window.becomesKeyOnlyIfNeeded = true

        // Keep window alive even when not key
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false

        // Show the window but don't activate it
        window.orderFront(nil)

        characterWindows[character.id] = window

        // Verify the actual window position after creation
        LoggerService.app.debug("   ✅ Widget window created:")
        LoggerService.app.debug("      Requested origin: \(NSStringFromPoint(requestedRect.origin))")
        LoggerService.app.debug("      Actual frame.origin: \(NSStringFromPoint(window.frame.origin))")
        LoggerService.app.debug("      Difference: (\(window.frame.origin.x - requestedRect.origin.x), \(window.frame.origin.y - requestedRect.origin.y))")
    }

    func removeCharacterWidget(id: UUID) {
        characterWindows[id]?.close()
        characterWindows.removeValue(forKey: id)
    }

    @MainActor
    func updateCharacter(_ character: Character, recreateWidget: Bool = true) {
        let oldCharacter = appState.character(withId: character.id)
        appState.updateCharacter(character)

        // Update reminders when character is updated
        ReminderService.shared.scheduleReminders(for: character)

        // Only recreate widget if visual properties changed or explicitly requested
        if recreateWidget, let old = oldCharacter {
            let needsRecreate = old.avatarAsset != character.avatarAsset ||
                               old.hasNotification != character.hasNotification ||
                               old.name != character.name

            if needsRecreate {
                removeCharacterWidget(id: character.id)
                createCharacterWidget(for: character)
            }
        }
    }

    // MARK: - Chat Window Management

    @MainActor
    func openChatWindow(for character: Character) {
        // If chat window already exists, bring it to front regardless of visibility
        // This prevents race conditions with context updates during window close
        if let existingWindow = self.chatWindows[character.id] {
            LoggerService.app.info("📱 Chat window already exists for \(character.name), bringing to front")
            existingWindow.orderOut(nil) // Hide it first
            existingWindow.makeKeyAndOrderFront(nil) // Then show and focus

            // Notify the view to scroll to bottom
            NotificationCenter.default.post(
                name: NSNotification.Name("ScrollChatToBottom"),
                object: character.id
            )
            return
        }

        LoggerService.app.info("📱 Creating new chat window for \(character.name)")

        // Create binding for isPresented (always true for window-based chat)
        let chatView = ChatWindow(
            characterId: character.id,
            appDelegate: self,
            isPresented: .constant(true)
        )

        // Position near the character widget if possible
        var chatWindowOrigin = NSPoint(x: 100, y: 100)
        if let characterWindow = characterWindows[character.id] {
            let characterFrame = characterWindow.frame
            // Position to the right of the character widget
            chatWindowOrigin = NSPoint(
                x: characterFrame.maxX + 20,
                y: characterFrame.minY
            )
        }

        let window = ChatPanel(
            contentRect: NSRect(origin: chatWindowOrigin, size: NSSize(width: 400, height: 500)),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.characterId = character.id
        window.title = "Chat with \(character.name)"
        window.contentView = NSHostingView(rootView: chatView)

        // Set min/max size constraints
        window.minSize = NSSize(width: 350, height: 400)
        window.maxSize = NSSize(width: 600, height: 800)

        // Custom titlebar style - unified toolbar look
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.toolbar = NSToolbar()
        window.toolbar?.displayMode = .iconOnly
        window.toolbarStyle = .unified

        // Window behavior - prevent menu bar activation
        window.isReleasedWhenClosed = false
        window.isFloatingPanel = false
        window.becomesKeyOnlyIfNeeded = true
        window.hidesOnDeactivate = false  // Don't hide when clicking away
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        // Set window delegate for proper lifecycle management
        window.delegate = self

        // Show the window without activating app in menu bar
        window.makeKeyAndOrderFront(nil)

        self.chatWindows[character.id] = window
    }

    func closeChatWindow(for characterId: UUID) {
        LoggerService.app.info("📱 Closing chat window for character ID: \(characterId)")
        self.chatWindows[characterId]?.close()
        self.chatWindows.removeValue(forKey: characterId)
        LoggerService.app.info("📱 Chat window removed from dictionary. Remaining windows: \(self.chatWindows.count)")
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? ChatPanel,
              let characterId = window.characterId else {
            return
        }

        LoggerService.app.info("🚪 Chat window will close for character: \(characterId)")

        // Trigger final context update via notification (non-blocking, completes in background)
        NotificationCenter.default.post(
            name: NSNotification.Name("ChatWindowWillClose"),
            object: nil,
            userInfo: ["characterId": characterId]
        )

        // Remove window immediately - context update will complete in background
        self.chatWindows.removeValue(forKey: characterId)
        LoggerService.app.info("📱 Chat window removed. Remaining windows: \(self.chatWindows.count)")
    }

    // MARK: - Notification Delegate Methods

    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            // Suppress notifications during initial launch or before onboarding completion
            if isInitialLaunch || !appState.settings.hasCompletedOnboarding {
                LoggerService.app.debug("🔕 Suppressing notification during initial launch/onboarding")
                completionHandler([])
                return
            }

            // Show notification even when app is in foreground
            completionHandler([.banner, .sound])

            // Set badge and store pending reminder
            if let characterIdString = notification.request.content.userInfo["characterId"] as? String,
               let characterId = UUID(uuidString: characterIdString),
               let reminderIdString = notification.request.content.userInfo["reminderId"] as? String,
               let reminderId = UUID(uuidString: reminderIdString) {
                setPendingReminder(for: characterId, reminderId: reminderId)
            }
        }
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            // Get character ID and reminder ID from notification
            if let characterIdString = response.notification.request.content.userInfo["characterId"] as? String,
               let characterId = UUID(uuidString: characterIdString),
               let reminderIdString = response.notification.request.content.userInfo["reminderId"] as? String,
               let reminderId = UUID(uuidString: reminderIdString) {
                setPendingReminder(for: characterId, reminderId: reminderId)

                // Open chat window for this character
                LoggerService.app.debug("📬 Notification tapped - opening chat for character ID: \(characterId)")
                if let character = appState.character(withId: characterId) {
                    openChatWindow(for: character)
                }
            }

            completionHandler()
        }
    }

    // MARK: - Reminder & Badge Management

    @MainActor
    func setPendingReminder(for characterId: UUID, reminderId: UUID) {
        appState.setPendingReminder(for: characterId, reminderId: reminderId)

        // Recreate the widget to show badge
        if let character = appState.character(withId: characterId) {
            removeCharacterWidget(id: characterId)
            createCharacterWidget(for: character)
        }
    }

    @MainActor
    func setNotificationBadge(for characterId: UUID, enabled: Bool) {
        appState.setNotificationBadge(for: characterId, enabled: enabled)

        // Recreate the widget to show/hide badge
        if let character = appState.character(withId: characterId) {
            removeCharacterWidget(id: characterId)
            createCharacterWidget(for: character)
        }
    }

}
