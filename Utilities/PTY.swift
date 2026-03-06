// PTY.swift
// Handles pseudo-terminal interaction.

import Foundation
import Darwin

@_silgen_name("forkpty")
func forkpty(_ amaster: UnsafeMutablePointer<Int32>,
             _ name: UnsafeMutablePointer<Int8>?,
             _ termp: UnsafeMutablePointer<termios>?,
             _ winp: UnsafeMutablePointer<winsize>?) -> pid_t

public class PTY {
    private var masterFD: Int32 = -1
    private var childPID: pid_t = -1
    private var masterHandle: FileHandle?
    private let stateLock = NSLock()
    private var didNotifyExit = false
    
    var onOutput: ((String) -> Void)?
    var onExit: (() -> Void)?
    
    private func withStateLock<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }
    
    func spawn(shell: String = "/bin/zsh", arguments: [String] = ["-i"], rows: UInt16 = 24, cols: UInt16 = 80) {
        guard !shell.isEmpty, FileManager.default.fileExists(atPath: shell) else {
            print("Invalid shell path: \(shell)")
            return
        }
        
        let alreadySpawned = withStateLock { childPID != -1 }
        guard !alreadySpawned else {
            print("PTY already spawned")
            return
        }
        
        var masterFD: Int32 = 0
        var ws = winsize(ws_row: rows, ws_col: cols, ws_xpixel: 0, ws_ypixel: 0)
        
        let pid = forkpty(&masterFD, nil, nil, &ws)
        
        if pid < 0 {
            print("forkpty failed")
            return
        }
        
        if pid == 0 {
            // Ensure PATH includes Homebrew before exec
            if let current = getenv("PATH") {
                let currentPath = String(cString: current)
                let brewPath = "/opt/homebrew/bin:" + currentPath
                setenv("PATH", brewPath, 1)
            } else {
                setenv("PATH", "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin", 1)
            }
            setenv("TERM", "xterm-256color", 1)

            let args = [shell] + arguments
            var cArgs: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) }
            cArgs.append(nil)
            
            defer {
                for ptr in cArgs {
                    if let ptr {
                        free(ptr)
                    }
                }
            }
            
            cArgs.withUnsafeMutableBufferPointer { buffer in
                _ = execvp(shell, buffer.baseAddress)
            }
            
            let message = String(cString: strerror(errno))
            fputs("execvp failed: \(message)\n", stderr)
            _exit(127)
        } else {
            // Parent
            let handle = FileHandle(fileDescriptor: masterFD, closeOnDealloc: true)
            withStateLock {
                self.masterFD = masterFD
                self.childPID = pid
                self.masterHandle = handle
                self.didNotifyExit = false
            }
            
            handle.readabilityHandler = { [weak self] handle in
                guard let self else { return }
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    self.handleProcessExit()
                    return
                }
                
                // Decode with replacement characters for invalid UTF-8 bytes.
                let output = String(decoding: data, as: UTF8.self)
                self.onOutput?(output)
            }
        }
    }
    
    func sendInput(_ input: String) {
        let handle = withStateLock { masterHandle }
        guard let handle else { return }
        guard let data = input.data(using: .utf8) else { return }
        do {
            try handle.write(contentsOf: data)
        } catch {
            print("Error writing to PTY: \(error)")
        }
    }
    
    func setWindowSize(rows: UInt16, cols: UInt16) {
        let fd = withStateLock { masterFD }
        guard fd >= 0, rows > 0, cols > 0 else { return }
        
        var ws = winsize(ws_row: rows, ws_col: cols, ws_xpixel: 0, ws_ypixel: 0)
        if ioctl(fd, UInt(TIOCSWINSZ), &ws) != 0 {
            print("Failed to set window size: \(String(cString: strerror(errno)))")
        }
    }
    
    private func handleProcessExit() {
        var pidToReap: pid_t = -1
        let shouldNotify = withStateLock { () -> Bool in
            if didNotifyExit { return false }
            didNotifyExit = true
            
            pidToReap = childPID
            childPID = -1
            masterFD = -1
            masterHandle = nil
            return true
        }
        
        if pidToReap > 0 {
            var status: Int32 = 0
            _ = waitpid(pidToReap, &status, WNOHANG)
        }
        
        if shouldNotify {
            onExit?()
        }
    }
    
    deinit {
        var handleToClose: FileHandle?
        var fdToClose: Int32 = -1
        var pidToKill: pid_t = -1
        
        withStateLock {
            handleToClose = masterHandle
            fdToClose = masterFD
            pidToKill = childPID
            
            masterHandle = nil
            masterFD = -1
            childPID = -1
            didNotifyExit = true
        }
        
        handleToClose?.readabilityHandler = nil
        if let handleToClose {
            try? handleToClose.close()
        } else if fdToClose >= 0 {
            close(fdToClose)
        }
        
        if pidToKill > 0 {
            kill(pidToKill, SIGHUP)
            var status: Int32 = 0
            _ = waitpid(pidToKill, &status, WNOHANG)
        }
    }
}
