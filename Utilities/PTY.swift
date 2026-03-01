// PTY.swift
// Handles pseudo-terminal interaction.

import Foundation
import Darwin

@_silgen_name("forkpty")
func forkpty(_ amaster: UnsafeMutablePointer<Int32>,
             _ name: UnsafeMutablePointer<Int8>?,
             _ termp: UnsafeMutablePointer<termios>?,
             _ winp: UnsafeMutablePointer<winsize>?) -> pid_t

class PTY {
    private var masterFD: Int32 = -1
    private var childPID: pid_t = -1
    private var masterHandle: FileHandle?
    
    var onOutput: ((String) -> Void)?
    var onExit: (() -> Void)?
    
    func spawn(shell: String = "/bin/zsh", arguments: [String] = ["-i"]) {
        guard !shell.isEmpty, FileManager.default.fileExists(atPath: shell) else {
            print("Invalid shell path: \(shell)")
            return
        }
        
        guard childPID == -1 else {
            print("PTY already spawned")
            return
        }
        var masterFD: Int32 = 0
        var ws = winsize(ws_row: 24, ws_col: 80, ws_xpixel: 0, ws_ypixel: 0)
        
        let pid = forkpty(&masterFD, nil, nil, &ws)
        
        if pid < 0 {
            print("forkpty failed")
            return
        }
        
            if pid == 0 {
                // Child
                let cArgs = ([shell] + arguments).map { strdup($0) } + [nil]
                defer {
                    for ptr in cArgs.compactMap({ $0 }) {
                        free(ptr)
                    }
                }
                execvp(shell, cArgs.compactMap { $0 })
                exit(1)
        } else {
            // Parent
            self.masterFD = masterFD
            self.childPID = pid
            let handle = FileHandle(fileDescriptor: masterFD, closeOnDealloc: true)
            self.masterHandle = handle
            
            handle.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if data.isEmpty {
                    self?.masterHandle?.readabilityHandler = nil
                    self?.onExit?()
                    return
                }
                
                // Handle potential non-UTF8 data by replacing invalid sequences
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self?.onOutput?(output)
                    }
                } else {
                    // Fallback: try to convert with lossy conversion for non-UTF8 data
                    if let lossyOutput = String(data: data, encoding: .isoLatin1) {
                        DispatchQueue.main.async {
                            self?.onOutput?(lossyOutput)
                        }
                    }
                }
            }
        }
    }
    
    func sendInput(_ input: String) {
        guard let data = input.data(using: .utf8) else { return }
        do {
            try masterHandle?.write(contentsOf: data)
        } catch {
            print("Error writing to PTY: \(error)")
            // Consider adding error handling callback or notification
        }
    }
    
    func setWindowSize(rows: UInt16, cols: UInt16) {
        guard rows > 0, cols > 0 else {
            print("Invalid window size: rows=\(rows), cols=\(cols)")
            return
        }
        
        var ws = winsize(ws_row: rows, ws_col: cols, ws_xpixel: 0, ws_ypixel: 0)
        _ = ioctl(masterFD, UInt(TIOCSWINSZ), &ws)
    }
    
    deinit {
        masterHandle?.readabilityHandler = nil
        if masterFD >= 0 {
            close(masterFD)
        }
        if childPID > 0 {
            kill(childPID, SIGTERM)
        }
    }
}