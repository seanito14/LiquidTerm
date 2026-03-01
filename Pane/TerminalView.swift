// TerminalView.swift
// Functional terminal view with PTY interaction and theme support.

import SwiftUI
import AppKit

struct TerminalView: NSViewRepresentable {
    @ObservedObject var session: TerminalSession
    @ObservedObject var tab: TabModel
    @EnvironmentObject var windowManager: WindowManager
    @EnvironmentObject var settings: SettingsStore
    
    @Binding var showSettings: Bool
    @Binding var showCommandPalette: Bool
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var session: TerminalSession?
        
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            if let input = replacementString {
                session?.sendInput(input)
            }
            return false
        }
    }
    
    class CustomNSTextView: NSTextView {
        var terminalView: TerminalView?
        
        override func menu(for event: NSEvent) -> NSMenu? {
            let menu = NSMenu(title: "Context Menu")
            
            guard let tv = terminalView else { return super.menu(for: event) }
            
            let newTabItem = NSMenuItem(title: "New Tab", action: #selector(handleNewTab), keyEquivalent: "t")
            newTabItem.target = self
            menu.addItem(newTabItem)
            
            let closeTabItem = NSMenuItem(title: "Close Tab", action: #selector(handleCloseTab), keyEquivalent: "w")
            closeTabItem.target = self
            menu.addItem(closeTabItem)
            
            menu.addItem(NSMenuItem.separator())
            
            let splitHorizontaItem = NSMenuItem(title: "Split Horizontally", action: #selector(handleSplitHorizontal), keyEquivalent: "")
            splitHorizontaItem.target = self
            menu.addItem(splitHorizontaItem)
            
            let splitVerticalItem = NSMenuItem(title: "Split Vertically", action: #selector(handleSplitVertical), keyEquivalent: "")
            splitVerticalItem.target = self
            menu.addItem(splitVerticalItem)
            
            let closeSplitItem = NSMenuItem(title: "Close Split", action: #selector(handleCloseSplit), keyEquivalent: "")
            closeSplitItem.target = self
            menu.addItem(closeSplitItem)
            
            menu.addItem(NSMenuItem.separator())
            
            let commandPaletteItem = NSMenuItem(title: "Command Palette", action: #selector(handleCommandPalette), keyEquivalent: "p")
            commandPaletteItem.target = self
            menu.addItem(commandPaletteItem)
            
            let settingsItem = NSMenuItem(title: "Settings", action: #selector(handleSettings), keyEquivalent: ",")
            settingsItem.target = self
            menu.addItem(settingsItem)
            
            return menu
        }
        
        @objc func handleNewTab() {
            terminalView?.windowManager.createNewTab()
        }
        
        @objc func handleCloseTab() {
            if let tabId = terminalView?.tab.id {
                terminalView?.windowManager.closeTab(id: tabId)
            }
        }
        
        @objc func handleSplitHorizontal() {
            terminalView?.windowManager.splitActiveTab(vertical: false)
        }
        
        @objc func handleSplitVertical() {
            terminalView?.windowManager.splitActiveTab(vertical: true)
        }
        
        @objc func handleCloseSplit() {
            if let sessionId = terminalView?.session.id {
                terminalView?.tab.removeSession(id: sessionId)
            }
        }
        
        @objc func handleCommandPalette() {
            terminalView?.showCommandPalette = true
        }
        
        @objc func handleSettings() {
            terminalView?.showSettings = true
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let textView = CustomNSTextView()
        textView.terminalView = self
        textView.delegate = context.coordinator
        context.coordinator.session = session
        
        textView.backgroundColor = .clear
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isEditable = true
        textView.insertionPointColor = NSColor(settings.cursorColor)
        
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? CustomNSTextView else { return }
        textView.terminalView = self
        
        // Update content
        if textView.string != session.output {
            textView.string = session.output
            textView.scrollToEndOfDocument(nil)
        }
        
        // Update font
        let fontSize = CGFloat(session.fontSize)
        let font = NSFont(name: settings.fontName, size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if textView.font != font {
            textView.font = font
        }
        
        // Update colors
        let textColor = NSColor(settings.currentTheme.textColor)
        if textView.textColor != textColor {
            textView.textColor = textColor
        }
        
        let cursorColor = NSColor(settings.cursorColor)
        if textView.insertionPointColor != cursorColor {
            textView.insertionPointColor = cursorColor
        }
        
        if settings.reduceTransparency {
            textView.backgroundColor = NSColor(settings.currentTheme.backgroundColor)
            nsView.drawsBackground = true
        } else {
            textView.backgroundColor = .clear
            nsView.drawsBackground = false
        }
    }
}