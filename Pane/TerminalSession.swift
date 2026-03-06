// TerminalSession.swift
// Represents a terminal session with PTY interaction and full terminal emulation.

import Foundation
import AppKit

class TerminalSession: Identifiable, ObservableObject {
    let id: UUID
    @Published var title: String
    @Published var fontSize: Double
    
    /// The terminal grid buffer — TerminalView reads this to render.
    let buffer: TerminalBuffer
    
    private let pty = PTY()
    private let parser: ANSIParser
    private var isActivated = false
    private var isSpawned = false
    private let outputQueue = DispatchQueue(label: "com.liquidterm.output", qos: .userInteractive)
    private var lastWindowSize: (rows: UInt16, cols: UInt16)?
    
    // Debounce for PTY resize after initial spawn
    private var resizeWorkItem: DispatchWorkItem?
    
    init(id: UUID = UUID(), title: String = "zsh", fontSize: Double = 14.0) {
        self.id = id
        self.title = title
        self.fontSize = fontSize
        // Start with default dimensions; resize happens before spawn
        self.buffer = TerminalBuffer(rows: 24, cols: 80)
        self.parser = ANSIParser(buffer: self.buffer)
    }
    
    /// Mark this session as ready. The actual PTY spawn is deferred until
    /// setSize() provides the real terminal dimensions from the view.
    func activate() {
        guard !isActivated else { return }
        isActivated = true
        
        // Wire up parser's response channel (for DSR, DA queries)
        parser.sendResponse = { [weak self] response in
            self?.pty.sendInput(response)
        }
    }
    
    private func spawnPTY(rows: UInt16, cols: UInt16) {
        guard !isSpawned else { return }
        isSpawned = true
        
        // Resize buffer to real dimensions before spawning
        buffer.resize(newRows: Int(rows), newCols: Int(cols))
        
        pty.onOutput = { [weak self] text in
            self?.handleOutput(text)
        }
        
        pty.onExit = { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                // Show exit message on the current line
                let msg = "\r\n[Process exited]\r\n"
                self.parser.feed(msg)
                self.objectWillChange.send()
            }
        }
        
        pty.spawn(rows: rows, cols: cols)
        lastWindowSize = (rows: rows, cols: cols)
    }
    
    private func handleOutput(_ text: String) {
        outputQueue.async { [weak self] in
            guard let self else { return }
            self.parser.feed(text)
            
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    func sendInput(_ input: String) {
        pty.sendInput(input)
    }
    
    func setSize(rows: UInt16, cols: UInt16) {
        guard rows > 0, cols > 0 else { return }
        
        // First valid size → spawn the shell with the correct dimensions
        if isActivated && !isSpawned {
            spawnPTY(rows: rows, cols: cols)
            return
        }
        
        // Skip if the size hasn't actually changed
        if let lastWindowSize, lastWindowSize.rows == rows, lastWindowSize.cols == cols {
            return
        }
        lastWindowSize = (rows: rows, cols: cols)
        
        // Debounce: coalesce rapid-fire SwiftUI layout passes into one resize
        resizeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.buffer.resize(newRows: Int(rows), newCols: Int(cols))
            self.pty.setWindowSize(rows: rows, cols: cols)
            self.objectWillChange.send()
        }
        resizeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
}
