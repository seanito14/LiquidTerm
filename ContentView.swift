// ContentView.swift
// Main container for the terminal with settings and theme support.

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
                
                // Hidden button to handle the Global Keyboard Shortcut
                Button("") {
                    showCommandPalette.toggle()
                }
                .buttonStyle(.plain)
                .keyboardShortcut("p", modifiers: [.command])
                .opacity(0)
                .frame(width: 0, height: 0)
            }
            
            if showSettings {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { showSettings = false }
                
                SettingsView()
                    .environmentObject(settings)
                    .frame(width: 400, height: 300)
                    .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
                    .cornerRadius(12)
                    .shadow(radius: 20)
                    .transition(.scale.combined(with: .opacity))
            }
            
            if showCommandPalette {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { showCommandPalette = false }
                
                CommandPalette(isPresented: $showCommandPalette)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(minWidth: 700, minHeight: 450)
        .environmentObject(windowManager)
        .onAppear {
            if let activeTab = windowManager.activeTab {
                for session in activeTab.sessions {
                    session.fontSize = settings.globalFontSize
                }
            }
        }
        .onChange(of: settings.globalFontSize) {
            if let activeTab = windowManager.activeTab {
                for session in activeTab.sessions {
                    session.fontSize = settings.globalFontSize
                }
            }
        }
    }
}
