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
        createNewTab()
        AppManager.shared.register(self)
    }
    
    deinit {
        AppManager.shared.unregister(self)
    }
    
    func createNewTab() {
        let index = tabs.count + 1
        let newSession = TerminalSession(title: "zsh")
        let newTab = TabModel(title: "Tab \(index)", sessions: [newSession])
        tabs.append(newTab)
        activeTabId = newTab.id
        newSession.activate()
    }
    
    func closeTab(id: UUID) {
        tabs.removeAll { $0.id == id }
        if activeTabId == id {
            activeTabId = tabs.last?.id
        }
        
        if tabs.isEmpty {
            createNewTab()
        }
    }
    
    func splitActiveTab(vertical: Bool) {
        guard let tab = activeTab else { return }
        tab.setPreferredSplitLayout(vertical: vertical)
        
        let newSession = TerminalSession(title: "zsh")
        tab.addSession(newSession)
        
        newSession.activate()
    }
    
    // Tab navigation
    func selectNextTab() {
        guard let currentId = activeTabId,
              let currentIndex = tabs.firstIndex(where: { $0.id == currentId }) else { return }
        let nextIndex = (currentIndex + 1) % tabs.count
        activeTabId = tabs[nextIndex].id
    }
    
    func selectPreviousTab() {
        guard let currentId = activeTabId,
              let currentIndex = tabs.firstIndex(where: { $0.id == currentId }) else { return }
        let prevIndex = (currentIndex - 1 + tabs.count) % tabs.count
        activeTabId = tabs[prevIndex].id
    }
}
