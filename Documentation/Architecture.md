# Architecture

## Modules

1. **WindowManager**: Handles `NSWindow` lifecycle and multi-window coordination.
2. **TabModel**: Manages tabs and active pane state.
3. **PaneLayout**: Resizable split stack for pane arrangement (supports horizontal/vertical splits).
4. **Terminal**: Core terminal emulation engine.
   - `TerminalCell`: Character + color/attribute model (16, 256, truecolor).
   - `TerminalBuffer`: Grid buffer with cursor, scroll regions, alternate screen, and `NSAttributedString` rendering.
   - `ANSIParser`: VT100/xterm escape sequence state machine (CSI, SGR, OSC, DEC private modes).
5. **TerminalView**: `NSViewRepresentable` bridging `NSScrollView` + `NSTextView`, renders the buffer grid as attributed text.
6. **TerminalSession**: Manages PTY lifecycle, feeds raw output through the parser into the buffer.
7. **SettingsStore**: Persists appearance settings (UserDefaults).

## Data Flow

```
WindowManager → TabModel → PaneLayout → TerminalView
                                              ↓
                                    TerminalSession (PTY)
                                              ↓
                                    ANSIParser → TerminalBuffer
                                              ↓
                                    TerminalView (renders NSAttributedString)
```

## Terminal Emulation

The terminal emulator supports:

- **Cursor movement**: CUU, CUD, CUF, CUB, CUP, CHA, VPA, etc.
- **Screen operations**: ED (erase display), EL (erase line), IL/DL (insert/delete lines), ICH/DCH (insert/delete chars)
- **Scrolling**: Scroll regions (DECSTBM), SU/SD (scroll up/down)
- **Colors**: Standard 16, 256-palette (6×6×6 cube + grayscale), 24-bit truecolor
- **Attributes**: Bold, dim, underline, inverse, strikethrough
- **Alternate screen**: DECSET/DECRST 1049 for htop, vim, nano, less
- **Device queries**: DSR (cursor position report), DA (device attributes)

## Security

- API keys stored in macOS Keychain (`kSecClassGenericPassword`).
- No logging of raw keys or sensitive output.
