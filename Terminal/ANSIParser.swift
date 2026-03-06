// Terminal/ANSIParser.swift
// VT100/xterm escape sequence parser — state machine that drives a TerminalBuffer.

import Foundation

class ANSIParser {
    private let buffer: TerminalBuffer
    
    /// Called when the terminal needs to send a response back to the PTY
    /// (e.g. cursor position report, device attributes).
    var sendResponse: ((String) -> Void)?
    
    private enum State {
        case ground
        case escape       // Just received ESC
        case csi          // ESC [  — collecting params
        case csiPrivate   // ESC [ ? — DEC private mode
        case osc          // ESC ]  — operating system command
        case oscEscape    // ESC ] ... ESC  (waiting for \)
        case dcs          // ESC P
        case dcsEscape    // ESC P ... ESC
    }
    
    private var state: State = .ground
    private var params: [Int] = []
    private var currentParam: String = ""
    private var oscString: String = ""
    
    init(buffer: TerminalBuffer) {
        self.buffer = buffer
    }
    
    // MARK: - Feed Data
    
    func feed(_ text: String) {
        for scalar in text.unicodeScalars {
            let code = scalar.value
            processChar(code)
        }
    }
    
    func feed(_ data: Data) {
        // Decode as UTF-8; process each unicode scalar
        let text = String(decoding: data, as: UTF8.self)
        feed(text)
    }
    
    // MARK: - State Machine
    
    private func processChar(_ code: UInt32) {
        switch state {
        case .ground:
            processGround(code)
        case .escape:
            processEscape(code)
        case .csi:
            processCSI(code, private: false)
        case .csiPrivate:
            processCSI(code, private: true)
        case .osc:
            processOSC(code)
        case .oscEscape:
            processOSCEscape(code)
        case .dcs:
            processDCS(code)
        case .dcsEscape:
            processDCSEscape(code)
        }
    }
    
    // MARK: - Ground State
    
    private func processGround(_ code: UInt32) {
        switch code {
        case 0x00: // NUL
            break
        case 0x07: // BEL
            break
        case 0x08: // BS
            buffer.backspace()
        case 0x09: // HT (tab)
            buffer.tab()
        case 0x0A, 0x0B, 0x0C: // LF, VT, FF
            buffer.index()
        case 0x0D: // CR
            buffer.carriageReturn()
        case 0x1B: // ESC
            state = .escape
        case 0x20...0x7E: // Printable ASCII
            buffer.putChar(Character(UnicodeScalar(code)!))
        case 0x7F: // DEL — ignore
            break
        default:
            // Pass through all other Unicode (CJK, emoji, etc.)
            if code >= 0x80 {
                if let scalar = UnicodeScalar(code) {
                    buffer.putChar(Character(scalar))
                }
            }
        }
    }
    
    // MARK: - Escape State
    
    private func processEscape(_ code: UInt32) {
        state = .ground
        switch code {
        case 0x5B: // [ → CSI
            params = []
            currentParam = ""
            state = .csi
        case 0x5D: // ] → OSC
            oscString = ""
            state = .osc
        case 0x50: // P → DCS
            state = .dcs
        case 0x4D: // M → Reverse Index
            buffer.reverseIndex()
        case 0x37: // 7 → DECSC (save cursor)
            buffer.saveCursor()
        case 0x38: // 8 → DECRC (restore cursor)
            buffer.restoreCursor()
        case 0x63: // c → RIS (full reset)
            buffer.fullReset()
        case 0x44: // D → IND (index / line feed)
            buffer.index()
        case 0x45: // E → NEL (next line)
            buffer.nextLine()
        default:
            // Unknown ESC sequence — ignore
            break
        }
    }
    
    // MARK: - CSI State
    
    private func processCSI(_ code: UInt32, private isPrivate: Bool) {
        switch code {
        case 0x3F: // '?' — switch to private mode
            if !isPrivate {
                state = .csiPrivate
            }
            return
            
        case 0x30...0x39: // '0'–'9' — accumulate digit
            currentParam.append(Character(UnicodeScalar(code)!))
            return
            
        case 0x3B: // ';' — parameter separator
            params.append(Int(currentParam) ?? 0)
            currentParam = ""
            return
            
        default:
            break
        }
        
        // Finalize the current parameter
        if !currentParam.isEmpty {
            params.append(Int(currentParam) ?? 0)
            currentParam = ""
        }
        
        state = .ground
        
        if isPrivate {
            dispatchCSIPrivate(code)
        } else {
            dispatchCSI(code)
        }
    }
    
    // MARK: - CSI Dispatch (standard)
    
    private func dispatchCSI(_ code: UInt32) {
        let p1 = params.first ?? 0
        
        switch code {
        case 0x41: // A — CUU (cursor up)
            buffer.moveCursorUp(max(1, p1))
            
        case 0x42: // B — CUD (cursor down)
            buffer.moveCursorDown(max(1, p1))
            
        case 0x43: // C — CUF (cursor forward)
            buffer.moveCursorForward(max(1, p1))
            
        case 0x44: // D — CUB (cursor backward)
            buffer.moveCursorBackward(max(1, p1))
            
        case 0x45: // E — CNL (cursor next line)
            buffer.moveCursorDown(max(1, p1))
            buffer.carriageReturn()
            
        case 0x46: // F — CPL (cursor previous line)
            buffer.moveCursorUp(max(1, p1))
            buffer.carriageReturn()
            
        case 0x47: // G — CHA (cursor horizontal absolute)
            buffer.setCursorCol(max(1, p1) - 1)
            
        case 0x48, 0x66: // H / f — CUP (cursor position)
            let row = max(1, params.count > 0 ? (params[0] == 0 ? 1 : params[0]) : 1) - 1
            let col = max(1, params.count > 1 ? (params[1] == 0 ? 1 : params[1]) : 1) - 1
            buffer.moveCursor(row: row, col: col)
            
        case 0x4A: // J — ED (erase in display)
            buffer.eraseInDisplay(p1)
            
        case 0x4B: // K — EL (erase in line)
            buffer.eraseInLine(p1)
            
        case 0x4C: // L — IL (insert lines)
            buffer.insertLines(max(1, p1))
            
        case 0x4D: // M — DL (delete lines)
            buffer.deleteLines(max(1, p1))
            
        case 0x50: // P — DCH (delete characters)
            buffer.deleteCharacters(max(1, p1))
            
        case 0x40: // @ — ICH (insert characters)
            buffer.insertCharacters(max(1, p1))
            
        case 0x58: // X — ECH (erase characters)
            buffer.eraseCharacters(max(1, p1))
            
        case 0x53: // S — SU (scroll up)
            buffer.scrollUp(max(1, p1))
            
        case 0x54: // T — SD (scroll down)
            buffer.scrollDown(max(1, p1))
            
        case 0x64: // d — VPA (vertical position absolute)
            buffer.setCursorRow(max(1, p1) - 1)
            
        case 0x6D: // m — SGR (set graphics rendition)
            handleSGR()
            
        case 0x72: // r — DECSTBM (set scroll region)
            let top = params.count > 0 && params[0] > 0 ? params[0] - 1 : 0
            let bottom = params.count > 1 && params[1] > 0 ? params[1] - 1 : buffer.rows - 1
            buffer.setScrollRegion(top: top, bottom: bottom)
            
        case 0x6E: // n — DSR (device status report)
            if p1 == 6 {
                // Cursor position report
                let response = "\u{1B}[\(buffer.cursorRow + 1);\(buffer.cursorCol + 1)R"
                sendResponse?(response)
            }
            
        case 0x63: // c — DA (device attributes)
            // Respond as VT220
            sendResponse?("\u{1B}[?62;1;2;6;7;8;9c")
            
        case 0x74: // t — window operations (ignored)
            break
            
        case 0x68: // h — SM (set mode, non-private)
            break
            
        case 0x6C: // l — RM (reset mode, non-private)
            break
            
        case 0x73: // s — SCP (save cursor position, legacy)
            buffer.saveCursor()
            
        case 0x75: // u — RCP (restore cursor position, legacy)
            buffer.restoreCursor()
            
        default:
            // Unknown CSI sequence — ignore
            break
        }
    }
    
    // MARK: - CSI Private Dispatch (DEC modes)
    
    private func dispatchCSIPrivate(_ code: UInt32) {
        switch code {
        case 0x68: // h — DECSET
            for p in params {
                setDECMode(p, enabled: true)
            }
        case 0x6C: // l — DECRST
            for p in params {
                setDECMode(p, enabled: false)
            }
        default:
            break
        }
    }
    
    private func setDECMode(_ mode: Int, enabled: Bool) {
        switch mode {
        case 1: // DECCKM (cursor keys mode) — we send application mode sequences in keyDown
            break
        case 7: // DECAWM (auto-wrap)
            buffer.autoWrapMode = enabled
        case 12: // Cursor blink — ignore
            break
        case 25: // DECTCEM (cursor visibility)
            buffer.cursorVisible = enabled
        case 47, 1047: // Alternate screen (without save/restore)
            if enabled { buffer.enableAltScreen() }
            else { buffer.disableAltScreen() }
        case 1049: // Alternate screen with save/restore cursor
            if enabled { buffer.enableAltScreen() }
            else { buffer.disableAltScreen() }
        case 2004: // Bracketed paste mode — acknowledge but no-op for now
            break
        case 1000, 1002, 1003, 1006, 1015: // Mouse tracking modes — ignore
            break
        default:
            break
        }
    }
    
    // MARK: - SGR (Set Graphics Rendition)
    
    private func handleSGR() {
        if params.isEmpty {
            buffer.currentAttributes = .default
            return
        }
        
        var i = 0
        while i < params.count {
            let p = params[i]
            switch p {
            case 0:
                buffer.currentAttributes = .default
            case 1:
                buffer.currentAttributes.bold = true
            case 2:
                buffer.currentAttributes.dim = true
            case 3: // Italic — treat as dim
                buffer.currentAttributes.dim = true
            case 4:
                buffer.currentAttributes.underline = true
            case 7:
                buffer.currentAttributes.inverse = true
            case 9:
                buffer.currentAttributes.strikethrough = true
            case 21: // Double underline → underline
                buffer.currentAttributes.underline = true
            case 22:
                buffer.currentAttributes.bold = false
                buffer.currentAttributes.dim = false
            case 23:
                buffer.currentAttributes.dim = false // un-italic
            case 24:
                buffer.currentAttributes.underline = false
            case 27:
                buffer.currentAttributes.inverse = false
            case 29:
                buffer.currentAttributes.strikethrough = false
                
            // Standard foreground colors (30–37)
            case 30...37:
                buffer.currentAttributes.fg = .standard(UInt8(p - 30))
            case 38:
                if let color = parseExtendedColor(from: params, startIndex: &i) {
                    buffer.currentAttributes.fg = color
                }
            case 39:
                buffer.currentAttributes.fg = .default
                
            // Standard background colors (40–47)
            case 40...47:
                buffer.currentAttributes.bg = .standard(UInt8(p - 40))
            case 48:
                if let color = parseExtendedColor(from: params, startIndex: &i) {
                    buffer.currentAttributes.bg = color
                }
            case 49:
                buffer.currentAttributes.bg = .default
                
            // Bright foreground colors (90–97)
            case 90...97:
                buffer.currentAttributes.fg = .standard(UInt8(p - 90 + 8))
                
            // Bright background colors (100–107)
            case 100...107:
                buffer.currentAttributes.bg = .standard(UInt8(p - 100 + 8))
                
            default:
                break
            }
            i += 1
        }
    }
    
    /// Parse 256-color (5;n) or truecolor (2;r;g;b) from SGR parameters.
    private func parseExtendedColor(from params: [Int], startIndex i: inout Int) -> TerminalColor? {
        guard i + 1 < params.count else { return nil }
        let mode = params[i + 1]
        switch mode {
        case 5: // 256-color
            guard i + 2 < params.count else { i += 1; return nil }
            let idx = params[i + 2]
            i += 2
            return .palette(UInt8(clamping: idx))
        case 2: // Truecolor
            guard i + 4 < params.count else { i += min(params.count - i - 1, 4); return nil }
            let r = UInt8(clamping: params[i + 2])
            let g = UInt8(clamping: params[i + 3])
            let b = UInt8(clamping: params[i + 4])
            i += 4
            return .rgb(r, g, b)
        default:
            i += 1
            return nil
        }
    }
    
    // MARK: - OSC State
    
    private func processOSC(_ code: UInt32) {
        switch code {
        case 0x07: // BEL — terminates OSC
            state = .ground
            // OSC content is in oscString — ignored for now
        case 0x1B: // ESC — might be ST (ESC \)
            state = .oscEscape
        default:
            oscString.append(Character(UnicodeScalar(code)!))
        }
    }
    
    private func processOSCEscape(_ code: UInt32) {
        state = .ground
        // 0x5C = '\' — ST terminator
        // Any other character: just end OSC
    }
    
    // MARK: - DCS State (Device Control String — ignored)
    
    private func processDCS(_ code: UInt32) {
        switch code {
        case 0x1B:
            state = .dcsEscape
        default:
            break // absorb
        }
    }
    
    private func processDCSEscape(_ code: UInt32) {
        state = .ground
    }
}
