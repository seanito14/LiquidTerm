// Terminal/TerminalCell.swift
// Character cell with display attributes for the terminal grid.

import AppKit

// MARK: - Terminal Color

enum TerminalColor: Equatable {
    case `default`
    case standard(UInt8)    // 0–15 (standard + bright)
    case palette(UInt8)     // 0–255
    case rgb(UInt8, UInt8, UInt8)
    
    // Standard 16 ANSI colors (matches xterm defaults)
    private static let standardColors: [(CGFloat, CGFloat, CGFloat)] = [
        (0.00, 0.00, 0.00), // 0  Black
        (0.80, 0.00, 0.00), // 1  Red
        (0.00, 0.80, 0.00), // 2  Green
        (0.80, 0.80, 0.00), // 3  Yellow
        (0.00, 0.00, 0.80), // 4  Blue
        (0.80, 0.00, 0.80), // 5  Magenta
        (0.00, 0.80, 0.80), // 6  Cyan
        (0.75, 0.75, 0.75), // 7  White
        (0.50, 0.50, 0.50), // 8  Bright Black
        (1.00, 0.33, 0.33), // 9  Bright Red
        (0.33, 1.00, 0.33), // 10 Bright Green
        (1.00, 1.00, 0.33), // 11 Bright Yellow
        (0.33, 0.33, 1.00), // 12 Bright Blue
        (1.00, 0.33, 1.00), // 13 Bright Magenta
        (0.33, 1.00, 1.00), // 14 Bright Cyan
        (1.00, 1.00, 1.00), // 15 Bright White
    ]
    
    func toNSColor(isForeground: Bool, defaultFG: NSColor, defaultBG: NSColor) -> NSColor {
        switch self {
        case .default:
            return isForeground ? defaultFG : defaultBG
        case .standard(let idx):
            let i = Int(min(idx, 15))
            let c = Self.standardColors[i]
            return NSColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        case .palette(let idx):
            return Self.paletteColor(idx)
        case .rgb(let r, let g, let b):
            return NSColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
        }
    }
    
    private static func paletteColor(_ idx: UInt8) -> NSColor {
        let i = Int(idx)
        if i < 16 {
            let c = standardColors[i]
            return NSColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        } else if i < 232 {
            // 6×6×6 color cube (indices 16–231)
            let adjusted = i - 16
            let ri = adjusted / 36
            let gi = (adjusted % 36) / 6
            let bi = adjusted % 6
            func component(_ v: Int) -> CGFloat {
                v == 0 ? 0 : CGFloat(55 + v * 40) / 255
            }
            return NSColor(red: component(ri), green: component(gi), blue: component(bi), alpha: 1)
        } else {
            // Grayscale (indices 232–255)
            let level = CGFloat(8 + (i - 232) * 10) / 255
            return NSColor(red: level, green: level, blue: level, alpha: 1)
        }
    }
}

// MARK: - Cell Attributes

struct CellAttributes: Equatable {
    var fg: TerminalColor = .default
    var bg: TerminalColor = .default
    var bold: Bool = false
    var dim: Bool = false
    var underline: Bool = false
    var inverse: Bool = false
    var strikethrough: Bool = false
    
    static let `default` = CellAttributes()
}

// MARK: - Terminal Cell

struct TerminalCell: Equatable {
    var character: Character = " "
    var attributes: CellAttributes = .default
    
    static let blank = TerminalCell()
}
