// WindowManager/WindowManager.swift
// Manages tabs and provides high-level control over the application's windows and sessions.

import Foundation
import SwiftUI
import Combine

class WindowManager: ObservableObject, Identifiable {
    let id = UUID()
    @Published var tabs: [TabModel] = []
    @Published var activeTabId: UUID?
    
    var activeTab: TabModel? {
        tabs.first { $0.id == activeTabId }
    }
    
    init() {
        // Initialize with a default tab if empty
        createNewTab()
        AppManager.shared.register(self)
    }
    
    deinit {
        AppManager.shared.unregister(self)
    }
    
    func createNewTab() {
        let newSession = TerminalSession(title: "zsh")
        let newTab = TabModel(title: "Tab \(tabs.count + 1)", sessions: [newSession])
        tabs.append(newTab)
        activeTabId = newTab.id
        newSession.activate()
    }
    
    func closeTab(id: UUID) {
        tabs.removeAll { $0.id == id }
        if activeTabId == id {
            activeTabId = tabs.first?.id
        }
        
        if tabs.isEmpty {
            createNewTab()
        }
    }
    
    func splitActiveTab(vertical: Bool) {
        guard let tab = activeTab else { return }
        let newSession = TerminalSession(title: "zsh")
        tab.addSession(newSession)
        tab.layout = vertical ? .verticalSplit : .horizontalSplit
        newSession.activate()
    }
}
