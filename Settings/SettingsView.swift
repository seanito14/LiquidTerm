// SettingsView.swift
// UI for adjusting terminal appearance and behavior.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    
    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $settings.currentTheme) {
                    ForEach(TerminalTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                
                Slider(value: $settings.backgroundOpacity, in: 0...1) {
                    Text("Opacity")
                } minimumValueLabel: {
                    Text("0%")
                } maximumValueLabel: {
                    Text("100%")
                }
                
                Slider(value: $settings.blurRadius, in: 0...50) {
                    Text("Blur Intensity")
                } minimumValueLabel: {
                    Text("0")
                } maximumValueLabel: {
                    Text("50")
                }
                
                Slider(value: $settings.cornerRadius, in: 0...40) {
                    Text("Corner Radius")
                }
                
                ColorPicker("Cursor Color", selection: Binding(
                    get: { settings.cursorColor },
                    set: { settings.cursorColor = $0 }
                ))
                
            }
            
            Section("Typography") {
                Slider(value: $settings.globalFontSize, in: 8...32, step: 1) {
                    Text("Font Size")
                } minimumValueLabel: {
                    Text("8pt")
                } maximumValueLabel: {
                    Text("32pt")
                }
                
                TextField("Font Name", text: $settings.fontName)
            }
            
            Section("Performance") {
                Toggle("Reduce Transparency", isOn: $settings.reduceTransparency)
            }
        }
        .padding()
        .frame(width: 450)
    }
}