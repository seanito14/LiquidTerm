// ContentView.swift
// Main container for the terminal with settings and theme support.

import SwiftUI

struct ContentView: View {
    @ObservedObject var session: TerminalSession
    @EnvironmentObject var settings: SettingsStore
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            LiquidBackground()
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                if settings.showTitleBar {
                    // Custom Title Bar
                    HStack {
                        Text(session.title)
                            .font(.caption)
                            .foregroundColor(settings.currentTheme.textColor.opacity(0.7))
                        
                        Spacer()
                        
                        Button(action: { showSettings.toggle() }) {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(settings.currentTheme.textColor.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showSettings) {
                            SettingsView()
                                .environmentObject(settings)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                } else {
                    // Minimal floating button for settings when title bar is hidden
                    HStack {
                        Spacer()
                        Button(action: { showSettings.toggle() }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 10))
                                .foregroundColor(settings.currentTheme.textColor.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                        .popover(isPresented: $showSettings) {
                            SettingsView()
                                .environmentObject(settings)
                        }
                    }
                }
                
                TerminalView(session: session)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
        }
        .frame(minWidth: 700, minHeight: 450)
        .onAppear {
            session.fontSize = settings.globalFontSize
            session.activate()
        }
        .onChange(of: settings.globalFontSize) { newValue in
            session.fontSize = newValue
        }
    }
}