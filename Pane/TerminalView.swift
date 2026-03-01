// TerminalView.swift
// Functional terminal view with PTY interaction and theme support.

import SwiftUI
import AppKit

struct TerminalView: NSViewRepresentable {
    @ObservedObject var session: TerminalSession
    @EnvironmentObject var settings: SettingsStore
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var session: TerminalSession?
        
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            if let input = replacementString {
                session?.sendInput(input)
            }
            return false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
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
        guard let textView = nsView.documentView as? NSTextView else { return }
        
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