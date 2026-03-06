# Developer Guide

## Setup

1. Clone repository.
2. Run `xcodegen` to generate `LiquidTerm.xcodeproj`.
3. Build for macOS 14+.

## Project Structure

```
/LiquidTerm
  ├── LiquidTermApp.swift          # Entry point
  ├── ContentView.swift            # Main container with overlays
  ├── CommandPalette.swift         # Command palette UI
  ├── Terminal/                    # Terminal emulation core
  │   ├── TerminalCell.swift       # Cell model (char + colors + attributes)
  │   ├── TerminalBuffer.swift     # Grid buffer (cursor, scroll, alt screen)
  │   └── ANSIParser.swift         # VT100/xterm escape sequence parser
  ├── Pane/                        # Pane layout + terminal view
  │   ├── TerminalSession.swift    # PTY session management
  │   ├── TerminalView.swift       # NSViewRepresentable terminal renderer
  │   ├── PaneLayout.swift         # Layout switching (single/split/grid)
  │   ├── PaneGrid.swift           # Grid container
  │   └── ResizableSplitStack.swift # Resizable dividers
  ├── WindowManager/               # Multi-window logic
  ├── Settings/                    # User preferences
  └── Utilities/                   # Helpers (PTY, VisualEffectView)
```

## Adding a New AI Provider

1. Conform to `AIProvider` protocol.
2. Add to `AIService.providers`.
3. Update `AIProvidersView` for UI.

## Testing

- **Unit Tests**: `PaneLayoutTests`, `AIServiceTests`.
- **UI Tests**: Multi-window workflows, accessibility audits.
