//
//  WigiAIApp.swift
//  WigiAI
//
//  AI Companion Desktop Widget
//

import SwiftUI

@main
struct WigiAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
