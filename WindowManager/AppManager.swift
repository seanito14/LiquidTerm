// WindowManager/AppManager.swift
// Global state manager to track open windows and handle cross-window tab transfers.

import Foundation
import SwiftUI
import Combine

class AppManager: ObservableObject {
    static let shared = AppManager()
    
    var windowManagers: [UUID: WindowManager] = [:]
    
    func register(_ windowManager: WindowManager) {
        windowManagers[windowManager.id] = windowManager
    }
    
    func unregister(_ windowManager: WindowManager) {
        windowManagers.removeValue(forKey: windowManager.id)
    }
    
    func moveTab(tabId: UUID, to destinationWindowManagerId: UUID) {
        var sourceWM: WindowManager?
        var foundTab: TabModel?
        
        for wm in windowManagers.values {
            if let tab = wm.tabs.first(where: { $0.id == tabId }) {
                foundTab = tab
                sourceWM = wm
                break
            }
        }
        
        guard let tab = foundTab, let source = sourceWM, let destination = windowManagers[destinationWindowManagerId] else { return }
        
        if source.id == destination.id { return }
        
        // Remove from source (without triggering close logic that makes new empty tabs if we don't want to)
        source.tabs.removeAll { $0.id == tabId }
        if source.activeTabId == tabId {
            source.activeTabId = source.tabs.first?.id
        }
        
        // Add to destination
        destination.tabs.append(tab)
        destination.activeTabId = tab.id
        
        // If source empty, create new tab or let the window close (if supported)
        if source.tabs.isEmpty {
            source.createNewTab()
        }
    }
}
