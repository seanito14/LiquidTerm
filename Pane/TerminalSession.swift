// TerminalSession.swift
// Represents a terminal session with PTY interaction and basic ANSI filtering.

import Foundation
import Combine

class TerminalSession: Identifiable, ObservableObject {
    let id: UUID
    @Published var title: String
    @Published var fontSize: Double
    @Published var output: String = ""
    
    private let pty = PTY()
    private let maxOutputLength = 100_000
    private var isStarted = false
    private let outputQueue = DispatchQueue(label: "com.liquidterm.output", qos: .userInteractive)
    
    init(id: UUID = UUID(), title: String = "zsh", fontSize: Double = 14.0) {
        self.id = id
        self.title = title
        self.fontSize = fontSize
    }
    
    func activate() {
        guard !isStarted else { return }
        isStarted = true
        setupPTY()
    }
    
    private func setupPTY() {
        pty.onOutput = { [weak self] text in
            self?.appendFilteredOutput(text)
        }
        
        pty.onExit = { [weak self] in
            self?.output += "\n[Process exited]\n"
        }
        
        pty.spawn()
    }
    
    private func appendFilteredOutput(_ text: String) {
        // Filter ANSI escape sequences (CSI and OSC)
        var filtered = text
            // Strip CSI sequences (e.g., colors, cursor movement, bracketed paste)
            .replacingOccurrences(
                of: #"\x1b\[[0-9;?=>]*[a-zA-Z]"#,
                with: "",
                options: .regularExpression
            )
            // Strip OSC sequences (e.g., window titles \x1b]0;...\\x07)
            .replacingOccurrences(
                of: #"\x1b\][^\x07]+\x07"#,
                with: "",
                options: .regularExpression
            )
            // Strip zsh PROMPT_EOL_MARK (typically % or # followed by spaces and carriage returns)
            .replacingOccurrences(
                of: #"[%#]\s*\r( \r)?"#,
                with: "",
                options: .regularExpression
            )
            // Strip remaining standalone carriage returns and bell characters
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\u{07}", with: "")
        
        outputQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.output += filtered
                
                // Trim buffer if too large
                if self.output.count > self.maxOutputLength {
                    self.output = String(self.output.suffix(self.maxOutputLength))
                }
            }
        }
    }
    
    func sendInput(_ input: String) {
        pty.sendInput(input)
    }
    
    func setSize(rows: UInt16, cols: UInt16) {
        pty.setWindowSize(rows: rows, cols: cols)
    }
}