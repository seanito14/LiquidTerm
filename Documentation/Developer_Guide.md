# Developer Guide

## Setup
1. Clone repository.
2. Run `xcodegen` to generate `LiquidTerm.xcodeproj`.
3. Build for macOS 14+.

## Project Structure
```
/LiquidTerm
  ├── LiquidTermApp.swift          # Entry point
  ├── WindowManager/               # Multi-window logic
  ├── Pane/                        # Pane layout + terminal
  ├── AI/                          # AI providers
  ├── Settings/                    # User preferences
  └── Utilities/                   # Helpers (Keychain, VisualEffectView)
```

## Adding a New AI Provider
1. Conform to `AIProvider` protocol.
2. Add to `AIService.providers`.
3. Update `AIProvidersView` for UI.

## Testing
- **Unit Tests**: `PaneLayoutTests`, `AIServiceTests`.
- **UI Tests**: Multi-window workflows, accessibility audits.