// LiquidTermApp.swift
// App entry point for LiquidTerm.

import SwiftUI

@main
struct LiquidTermApp: App {
    @StateObject private var settings = SettingsStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .onAppear {
                    configureExistingWindows()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeMainNotification)) { note in
                    guard let window = note.object as? NSWindow else { return }
                    configure(window: window)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Remove the default "Window > Show Tab Bar" menu
            CommandGroup(replacing: .windowList) {}
        }
    }
    
    private func configureExistingWindows() {
        NSWindow.allowsAutomaticWindowTabbing = false
        for window in NSApplication.shared.windows {
            configure(window: window)
        }
    }
    
    private func configure(window: NSWindow) {
        window.tabbingMode = .disallowed
        window.toolbar = nil
        window.standardWindowButton(.toolbarButton)?.isHidden = true
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.styleMask.insert(.fullSizeContentView)
    }
}

// MARK: - Notification Names for global commands
extension Notification.Name {
    static let splitHorizontal = Notification.Name("com.liquidterm.splitHorizontal")
    static let splitVertical = Notification.Name("com.liquidterm.splitVertical")
    static let closePane = Notification.Name("com.liquidterm.closePane")
    static let toggleSettings = Notification.Name("com.liquidterm.toggleSettings")
}
