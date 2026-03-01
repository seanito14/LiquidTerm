// SettingsStore.swift
// Manages user settings with persistence.

import SwiftUI

enum TerminalTheme: String, CaseIterable, Codable {
    case liquid = "Liquid"
    case dark = "Classic Dark"
    case light = "Classic Light"
    case matrix = "Matrix"
    case ocean = "Deep Ocean"
    
    var backgroundColor: Color {
        switch self {
        case .liquid: return Color.black.opacity(0.4)
        case .dark: return Color.black
        case .light: return Color.white
        case .matrix: return Color.black
        case .ocean: return Color(red: 0.05, green: 0.1, blue: 0.2)
        }
    }
    
    var textColor: Color {
        switch self {
        case .liquid: return .white
        case .dark: return .white
        case .light: return .black
        case .matrix: return .green
        case .ocean: return Color(red: 0.4, green: 0.8, blue: 1.0)
        }
    }
}

class SettingsStore: ObservableObject {
    @AppStorage("globalFontSize") var globalFontSize: Double = 14
    @AppStorage("reduceTransparency") var reduceTransparency: Bool = false
    @AppStorage("cornerRadius") var cornerRadius: Double = 12
    @AppStorage("backgroundOpacity") var backgroundOpacity: Double = 0.6
    @AppStorage("blurRadius") var blurRadius: Double = 20.0
    @AppStorage("currentTheme") var currentTheme: TerminalTheme = .liquid
    @AppStorage("fontName") var fontName: String = "SF Mono"
    @AppStorage("showTitleBar") var showTitleBar: Bool = true
    @AppStorage("cursorColorHex") var cursorColorHex: String = "#FFFFFF"
    
    @Published var aiProviders: [AIProviderConfig] = []
    
    var cursorColor: Color {
        get { Color(hex: cursorColorHex) ?? .white }
        set { cursorColorHex = newValue.toHex() ?? "#FFFFFF" }
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }

    func toHex() -> String? {
        let uicov = NSColor(self)
        guard let rgbColor = uicov.usingColorSpace(.deviceRGB) else { return nil }
        let red = Int(rgbColor.redComponent * 255)
        let green = Int(rgbColor.greenComponent * 255)
        let blue = Int(rgbColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

struct AIProviderConfig: Codable, Identifiable {
    let id: UUID
    var name: String
    var baseURL: String
    var apiKey: String
    var defaultModel: String
}
