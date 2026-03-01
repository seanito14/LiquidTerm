// VisualEffectView.swift
// SwiftUI wrapper for NSVisualEffectView with adjustable blur.

import SwiftUI

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// Extension to apply custom blur via CAFilter if needed, 
// but standard NSVisualEffectView materials are usually enough.
// For true custom blur intensity, we can use a Backdrop filter.
struct LiquidBackground: View {
    @EnvironmentObject var settings: SettingsStore
    
    var body: some View {
        ZStack {
            if !settings.reduceTransparency {
                VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
                    .overlay(settings.currentTheme.backgroundColor.opacity(settings.backgroundOpacity))
                    .blur(radius: settings.blurRadius)
            } else {
                settings.currentTheme.backgroundColor
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: settings.cornerRadius))
    }
}