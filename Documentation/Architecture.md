# Architecture

## Modules
1. **WindowManager**: Handles `NSWindow` lifecycle and multi-window coordination.
2. **TabModel**: Manages tabs and active pane state.
3. **PaneLayout**: Binary split tree for pane arrangement (supports splits, closes, zooms).
4. **TerminalView**: Stub for Phase 1; later integrates PTY via `NSViewRepresentable`.
5. **AIService**: Protocol-based provider system (OpenAI, Anthropic, Local).
6. **SettingsStore**: Persists appearance/AI settings (UserDefaults + Keychain).

## Data Flow
```
WindowManager → TabModel → PaneLayout → TerminalView
                     ↓
               AIService (explain/generate)
                     ↓
               Keychain (secure storage)
```

## Security
- API keys stored in macOS Keychain (`kSecClassGenericPassword`).
- Redaction layer masks secrets (e.g., `AWS_SECRET_ACCESS_KEY=...`).
- No logging of raw keys or sensitive output.

## Phase 2 Roadmap
1. Replace `TerminalView` stub with real PTY (`forkpty` + ANSI parsing).
2. Add Metal-backed text rendering for performance.
3. Implement session persistence (JSON + `Codable`).