// ContentView.swift
// Main container for the terminal — ultra-minimal, no chrome.

import SwiftUI

struct ContentView: View {
    @StateObject var windowManager = WindowManager()
    @EnvironmentObject var settings: SettingsStore
    @State private var showSettings = false
    @State private var showCommandPalette = false
    
    var body: some View {
        ZStack {
            LiquidBackground()
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                if let activeTab = windowManager.activeTab {
                    PaneGrid(tab: activeTab, showSettings: $showSettings, showCommandPalette: $showCommandPalette)
                } else {
                    Spacer()
                    Text("No Active Sessions")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            
            // Settings overlay
            if showSettings {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { showSettings = false } }
                
                SettingsView()
                    .environmentObject(settings)
                    .frame(width: 450, height: 380)
                    .background(
                        VisualEffectView(material: .popover, blendingMode: .behindWindow)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 30)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            
            // Command palette overlay
            if showCommandPalette {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { showCommandPalette = false } }
                
                CommandPalette(isPresented: $showCommandPalette)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .frame(minWidth: 500, minHeight: 300)
        .environmentObject(windowManager)
        .onAppear {
            applyFontSizeToAllSessions()
        }
        .onChange(of: settings.globalFontSize) {
            applyFontSizeToAllSessions()
        }
        // Global keyboard shortcuts via hidden buttons
        .background(
            Group {
                Button("") { toggleCommandPalette() }
                    .keyboardShortcut("p", modifiers: .command)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                
                Button("") { windowManager.splitActiveTab(vertical: true) }
                    .keyboardShortcut("d", modifiers: .command)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                
                Button("") { windowManager.splitActiveTab(vertical: false) }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                    .opacity(0)
                    .frame(width: 0, height: 0)
                
                Button("") { closeActivePane() }
                    .keyboardShortcut("w", modifiers: .command)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                
                Button("") { toggleSettings() }
                    .keyboardShortcut(",", modifiers: .command)
                    .opacity(0)
                    .frame(width: 0, height: 0)
            }
        )
        // Listen for global notification-based commands
        .onReceive(NotificationCenter.default.publisher(for: .splitHorizontal)) { _ in
            windowManager.splitActiveTab(vertical: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .splitVertical)) { _ in
            windowManager.splitActiveTab(vertical: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .closePane)) { _ in
            closeActivePane()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSettings)) { _ in
            toggleSettings()
        }
    }
    
    private func applyFontSizeToAllSessions() {
        for tab in windowManager.tabs {
            for session in tab.sessions {
                session.fontSize = settings.globalFontSize
            }
        }
    }
    
    private func closeActivePane() {
        guard let tab = windowManager.activeTab else { return }
        if tab.sessions.count > 1, let activeSessionId = tab.activeSessionId {
            tab.removeSession(id: activeSessionId)
        } else {
            windowManager.closeTab(id: tab.id)
        }
    }
    
    private func toggleSettings() {
        withAnimation(.easeOut(duration: 0.15)) {
            if showSettings {
                showSettings = false
            } else {
                showCommandPalette = false
                showSettings = true
            }
        }
    }
    
    private func toggleCommandPalette() {
        withAnimation(.easeOut(duration: 0.15)) {
            if showCommandPalette {
                showCommandPalette = false
            } else {
                showSettings = false
                showCommandPalette = true
            }
        }
    }
}
