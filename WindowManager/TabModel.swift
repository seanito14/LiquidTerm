// WindowManager/TabModel.swift
// Representation of a terminal tab containing one or more panes.

import Foundation
import Combine

class TabModel: Identifiable, ObservableObject {
    let id: UUID
    @Published var title: String
    @Published var sessions: [TerminalSession]
    @Published var activeSessionId: UUID?
    @Published var layout: PaneLayoutType
    @Published var sessionFractions: [CGFloat]
    
    init(id: UUID = UUID(), title: String = "Tab", sessions: [TerminalSession] = [], layout: PaneLayoutType = .single) {
        self.id = id
        self.title = title
        self.sessions = sessions
        self.layout = layout
        self.activeSessionId = sessions.first?.id
        
        if sessions.isEmpty {
            self.sessionFractions = []
        } else {
            let initialFraction = 1.0 / CGFloat(sessions.count)
            self.sessionFractions = Array(repeating: initialFraction, count: sessions.count)
        }
    }
    
    func addSession(_ session: TerminalSession) {
        sessions.append(session)
        if activeSessionId == nil {
            activeSessionId = session.id
            sessionFractions = [1.0]
        } else {
            // Find the active session to split its fraction
            if let activeId = activeSessionId, let activeIndex = sessions.firstIndex(where: { $0.id == activeId }) {
                // The new session is added at the end, but we need to split the fraction of the active session
                // Since this simple array of fractions maps to the sessions array, we just update the fractions
                var currentFractions = sessionFractions
                let activeFraction = currentFractions[activeIndex]
                let splitFraction = activeFraction / 2.0
                currentFractions[activeIndex] = splitFraction
                currentFractions.append(splitFraction)
                sessionFractions = currentFractions
            } else {
                // Fallback if no active session found
                let count = max(1, sessions.count)
                sessionFractions = Array(repeating: 1.0 / CGFloat(count), count: count)
            }
            activeSessionId = session.id
        }
    }
    
    func removeSession(id: UUID) {
        guard let indexToRemove = sessions.firstIndex(where: { $0.id == id }) else { return }
        
        let removedFraction = sessionFractions[indexToRemove]
        sessions.remove(at: indexToRemove)
        sessionFractions.remove(at: indexToRemove)
        
        if activeSessionId == id {
            activeSessionId = sessions.first?.id
        }
        
        guard !sessions.isEmpty else { return }
        
        // Give the removed fraction to the adjacent session (preferring the one before it, or after if it was first)
        let targetIndex = max(0, indexToRemove - 1)
        if targetIndex < sessionFractions.count {
            sessionFractions[targetIndex] += removedFraction
        }
    }
}

enum PaneLayoutType: String, Codable, CaseIterable {
    case single
    case horizontalSplit
    case verticalSplit
    case grid
}
