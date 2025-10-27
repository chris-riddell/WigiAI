//
//  WindowMoveObserver.swift
//  WigiAI
//
//  ViewModifier for observing window move events
//

import SwiftUI
import OSLog

/// ViewModifier that observes window move events and updates character position
///
/// **Performance Optimization:**
/// Debounces position saves to disk - only saves after 500ms of no movement.
/// This prevents hundreds of disk writes during window dragging.
struct WindowMoveObserver: ViewModifier {
    let characterId: UUID
    let appDelegate: AppDelegate

    @State private var observer: NSObjectProtocol?
    @State private var debouncedSaveTask: DispatchWorkItem?

    /// Debounce interval for position saving (milliseconds)
    private let debounceInterval: TimeInterval = 0.5

    func body(content: Content) -> some View {
        content.onAppear {
            // Add observer for window move events and store it for cleanup
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didMoveNotification,
                object: nil,
                queue: .main
            ) { notification in
                // Only handle notifications for this character's widget
                guard let window = notification.object as? NSWindow,
                      let panel = window as? CharacterPanel,
                      panel.characterId == characterId else {
                    return
                }

                let newOrigin = window.frame.origin

                // Cancel any pending save task
                debouncedSaveTask?.cancel()

                // Schedule a new save task after debounce interval
                let task = DispatchWorkItem { [weak appDelegate] in
                    // Ensure we're on the main actor for AppState updates
                    Task { @MainActor in
                        appDelegate?.appState.updateCharacterPosition(id: characterId, position: newOrigin)
                        LoggerService.ui.debug("💾 Widget position saved: (\(newOrigin.x), \(newOrigin.y))")
                    }
                }

                debouncedSaveTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: task)
            }
        }
        .onDisappear {
            // Save immediately if there's a pending position update
            if let task = debouncedSaveTask, !task.isCancelled {
                task.cancel()
                // Get the current window position and save it immediately
                if let window = NSApp.windows.first(where: { ($0 as? CharacterPanel)?.characterId == characterId }) {
                    let finalPosition = window.frame.origin
                    // Use MainActor to ensure safe access to AppState
                    Task { @MainActor in
                        appDelegate.appState.updateCharacterPosition(id: characterId, position: finalPosition)
                        LoggerService.ui.debug("💾 Final widget position saved on disappear: (\(finalPosition.x), \(finalPosition.y))")
                    }
                }
            }

            // CRITICAL: Remove observer to prevent memory leak
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
                LoggerService.ui.debug("🧹 Removed window move observer for character: \(characterId)")
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Observes window move events for a character widget
    /// - Parameters:
    ///   - characterId: The ID of the character
    ///   - appDelegate: The app delegate
    /// - Returns: Modified view with window move observation
    func observeWindowMove(characterId: UUID, appDelegate: AppDelegate) -> some View {
        modifier(WindowMoveObserver(characterId: characterId, appDelegate: appDelegate))
    }
}
