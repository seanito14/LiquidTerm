// TerminalView.swift
// Functional terminal view with PTY interaction, theme support, and context menu.
// Renders a TerminalBuffer grid as NSAttributedString.

import SwiftUI
import AppKit

struct TerminalView: NSViewRepresentable {
    @ObservedObject var session: TerminalSession
    @ObservedObject var tab: TabModel
    @EnvironmentObject var windowManager: WindowManager
    @EnvironmentObject var settings: SettingsStore
    
    @Binding var showSettings: Bool
    @Binding var showCommandPalette: Bool
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var session: TerminalSession?
        var parent: TerminalView?
        /// Tracks the last buffer generation we rendered.
        var lastAppliedGeneration: UInt64 = 0
        
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            if let input = replacementString {
                session?.sendInput(input)
            }
            return false
        }
    }
    
    // MARK: - Custom NSTextView
    
    class TerminalNSTextView: NSTextView {
        weak var coordinator: Coordinator?
        
        private func markSessionFocused() {
            guard let parent = coordinator?.parent else { return }
            parent.tab.focusSession(parent.session.id)
        }
        
        override func mouseDown(with event: NSEvent) {
            markSessionFocused()
            super.mouseDown(with: event)
        }
        
        override func becomeFirstResponder() -> Bool {
            let became = super.becomeFirstResponder()
            if became {
                markSessionFocused()
            }
            return became
        }
        
        override func menu(for event: NSEvent) -> NSMenu? {
            let menu = NSMenu(title: "Terminal")
            
            // Copy/Paste
            if selectedRange().length > 0 {
                menu.addItem(withTitle: "Copy", action: #selector(copy(_:)), keyEquivalent: "c")
            }
            menu.addItem(withTitle: "Paste", action: #selector(pasteText), keyEquivalent: "v")
            
            menu.addItem(NSMenuItem.separator())
            
            // Split management
            let splitHItem = NSMenuItem(title: "Split Horizontally", action: #selector(handleSplitHorizontal), keyEquivalent: "")
            splitHItem.target = self
            menu.addItem(splitHItem)
            
            let splitVItem = NSMenuItem(title: "Split Vertically", action: #selector(handleSplitVertical), keyEquivalent: "")
            splitVItem.target = self
            menu.addItem(splitVItem)
            
            let closeSplitItem = NSMenuItem(title: "Close Split", action: #selector(handleCloseSplit), keyEquivalent: "")
            closeSplitItem.target = self
            menu.addItem(closeSplitItem)
            
            menu.addItem(NSMenuItem.separator())
            
            // Tools
            let cmdPaletteItem = NSMenuItem(title: "Command Palette", action: #selector(handleCommandPalette), keyEquivalent: "")
            cmdPaletteItem.target = self
            menu.addItem(cmdPaletteItem)
            
            let settingsItem = NSMenuItem(title: "Settings", action: #selector(handleSettings), keyEquivalent: "")
            settingsItem.target = self
            menu.addItem(settingsItem)
            
            return menu
        }
        
        // Handle special keys (arrow keys, backspace, etc.)
        override func keyDown(with event: NSEvent) {
            markSessionFocused()
            
            guard let session = coordinator?.session else {
                super.keyDown(with: event)
                return
            }
            
            // Handle modifier + key combos (Ctrl+C, Ctrl+D, etc.)
            if event.modifierFlags.contains(.control) {
                if let chars = event.charactersIgnoringModifiers, let scalar = chars.unicodeScalars.first {
                    // Map Ctrl+A through Ctrl+Z to ASCII control characters
                    let val = scalar.value
                    let controlValue: UInt32?
                    
                    if (97...122).contains(val) { // a-z
                        controlValue = val - 96
                    } else if (65...90).contains(val) { // A-Z
                        controlValue = val - 64
                    } else {
                        controlValue = nil
                    }
                    
                    if let controlValue, let controlScalar = UnicodeScalar(controlValue) {
                        session.sendInput(String(controlScalar))
                        return
                    }
                }
            }
            
            switch Int(event.keyCode) {
            case 126: session.sendInput("\u{1b}[A") // Up
            case 125: session.sendInput("\u{1b}[B") // Down
            case 124: session.sendInput("\u{1b}[C") // Right
            case 123: session.sendInput("\u{1b}[D") // Left
            case 51:  session.sendInput("\u{7f}") // Backspace (DEL)
            case 117: session.sendInput("\u{1b}[3~") // Delete (forward)
            case 115: session.sendInput("\u{1b}[H")  // Home
            case 119: session.sendInput("\u{1b}[F")  // End
            case 116: session.sendInput("\u{1b}[5~") // Page Up
            case 121: session.sendInput("\u{1b}[6~") // Page Down
            case 53:  session.sendInput("\u{1b}")     // Escape
            case 48:  session.sendInput("\t")         // Tab
            case 36:  session.sendInput("\n")         // Return
            default:
                // Let the delegate's shouldChangeText handle regular text input
                super.keyDown(with: event)
            }
        }
        
        override func deleteBackward(_ sender: Any?) {
            markSessionFocused()
            coordinator?.session?.sendInput("\u{7f}")
        }
        
        @objc func pasteText() {
            if let text = NSPasteboard.general.string(forType: .string) {
                coordinator?.session?.sendInput(text)
            }
        }
        
        @objc func handleCloseTab() {
            if let tabId = coordinator?.parent?.tab.id {
                coordinator?.parent?.windowManager.closeTab(id: tabId)
            }
        }
        
        @objc func handleSplitHorizontal() {
            coordinator?.parent?.windowManager.splitActiveTab(vertical: false)
        }
        
        @objc func handleSplitVertical() {
            coordinator?.parent?.windowManager.splitActiveTab(vertical: true)
        }
        
        @objc func handleCloseSplit() {
            guard let parent = coordinator?.parent else { return }
            let tab = parent.tab
            if tab.sessions.count > 1 {
                tab.removeSession(id: parent.session.id)
                if tab.sessions.count == 1 {
                    tab.layout = .single
                }
            }
        }
        
        @objc func handleCommandPalette() {
            coordinator?.parent?.showSettings = false
            coordinator?.parent?.showCommandPalette = true
        }
        
        @objc func handleSettings() {
            NotificationCenter.default.post(name: .toggleSettings, object: nil)
        }
    }
    
    // MARK: - NSViewRepresentable
    
    func makeCoordinator() -> Coordinator {
        let c = Coordinator()
        c.session = session
        c.parent = self
        return c
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let textView = TerminalNSTextView()
        textView.coordinator = context.coordinator
        textView.delegate = context.coordinator
        
        // Appearance
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.insertionPointColor = NSColor(settings.cursorColor)
        
        // Behavior
        textView.isEditable = true
        textView.isRichText = true  // Required for attributed strings
        textView.allowsUndo = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        
        // Layout
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 4, height: 4)
        
        // Use fixed-width line fragment padding for consistent monospace alignment
        textView.textContainer?.lineFragmentPadding = 0
        
        // ScrollView
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        
        // Set initial content
        applyContent(to: textView, coordinator: context.coordinator)
        applyStyle(to: textView)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? TerminalNSTextView else { return }
        
        // Keep coordinator references fresh
        context.coordinator.session = session
        context.coordinator.parent = self
        textView.coordinator = context.coordinator
        
        applyContent(to: textView, coordinator: context.coordinator)
        applyStyle(to: textView)
        
        // Update PTY window size based on visible area
        updatePTYSize(textView: textView, scrollView: nsView)
    }
    
    // MARK: - Helpers
    
    private func applyContent(to textView: TerminalNSTextView, coordinator: Coordinator) {
        let currentGen = session.buffer.generation
        guard currentGen != coordinator.lastAppliedGeneration else { return }
        coordinator.lastAppliedGeneration = currentGen
        
        let fontSize = CGFloat(session.fontSize)
        let font = NSFont(name: settings.fontName, size: fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let defaultFG = NSColor(settings.currentTheme.textColor)
        let defaultBG: NSColor
        if settings.reduceTransparency {
            defaultBG = NSColor(settings.currentTheme.backgroundColor)
        } else {
            defaultBG = .clear
        }
        
        let attrString = session.buffer.toAttributedString(
            font: font,
            defaultFG: defaultFG,
            defaultBG: defaultBG
        )
        
        textView.textStorage?.setAttributedString(attrString)
        
        // Position cursor at the buffer's cursor location for the insertion point
        let buf = session.buffer
        let charIndex = buf.cursorRow * (buf.cols + 1) + buf.cursorCol  // +1 for newlines
        let safeIndex = min(max(0, charIndex), textView.string.count)
        textView.setSelectedRange(NSRange(location: safeIndex, length: 0))
        
        // Auto-scroll to bottom
        textView.scrollToEndOfDocument(nil)
    }
    
    private func applyStyle(to textView: NSTextView) {
        let cursorColor = NSColor(settings.cursorColor)
        if textView.insertionPointColor != cursorColor {
            textView.insertionPointColor = cursorColor
        }
        
        if settings.reduceTransparency {
            textView.backgroundColor = NSColor(settings.currentTheme.backgroundColor)
            (textView.enclosingScrollView)?.drawsBackground = true
        } else {
            textView.backgroundColor = .clear
            (textView.enclosingScrollView)?.drawsBackground = false
        }
    }
    
    private func updatePTYSize(textView: NSTextView, scrollView: NSScrollView) {
        let fontSize = CGFloat(session.fontSize)
        let font = textView.font ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let charSize = ("M" as NSString).size(withAttributes: attrs)
        
        guard charSize.width > 0, charSize.height > 0 else { return }
        
        let visibleSize = scrollView.documentVisibleRect.size
        let inset = textView.textContainerInset
        let usableWidth = visibleSize.width - (inset.width * 2)
        let usableHeight = visibleSize.height - (inset.height * 2)
        
        let cols = safeTerminalDimension(usableWidth / charSize.width)
        let rows = safeTerminalDimension(usableHeight / charSize.height)
        
        session.setSize(rows: rows, cols: cols)
    }
    
    private func safeTerminalDimension(_ value: CGFloat) -> UInt16 {
        guard value.isFinite else { return 1 }
        
        let floored = floor(value)
        if floored <= 1 {
            return 1
        }
        
        if floored >= CGFloat(UInt16.max) {
            return UInt16.max
        }
        
        return UInt16(floored)
    }
}
