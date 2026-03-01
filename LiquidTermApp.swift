// LiquidTermApp.swift
// App entry point for LiquidTerm.

import SwiftUI

@main
struct LiquidTermApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var session = TerminalSession()
    
    var body: some Scene {
        WindowGroup {
            ContentView(session: session)
                .environmentObject(settings)
                .onAppear {
                    // Set window background to clear so the visual effect view works
                    if let window = NSApplication.shared.windows.first {
                        window.isOpaque = false
                        window.backgroundColor = .clear
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
}