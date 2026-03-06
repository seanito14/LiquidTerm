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
    @Published var preferredSplitLayout: PaneLayoutType
    
    init(id: UUID = UUID(), title: String = "Tab", sessions: [TerminalSession] = [], layout: PaneLayoutType = .single) {
        self.id = id
        self.title = title
        self.sessions = sessions
        self.layout = layout
        self.activeSessionId = sessions.first?.id
        self.preferredSplitLayout = layout == .verticalSplit ? .verticalSplit : .horizontalSplit
        self.sessionFractions = Self.evenFractions(count: sessions.count)
    }
    
    func addSession(_ session: TerminalSession) {
        sessions.append(session)
        
        // Split the active session's fraction in half for the new pane if possible.
        let minFraction: CGFloat = 0.02
        if let activeId = activeSessionId,
           let activeIndex = sessions.dropLast().firstIndex(where: { $0.id == activeId }),
           activeIndex < sessionFractions.count,
           sessionFractions.count == sessions.count - 1,
           sessionFractions[activeIndex].isFinite,
           sessionFractions[activeIndex] > minFraction * 2 {
            let activeFraction = sessionFractions[activeIndex]
            let splitSize = max(minFraction, activeFraction / 2.0)
            let retainedSize = activeFraction - splitSize
            if retainedSize.isFinite, retainedSize > 0 {
                sessionFractions[activeIndex] = retainedSize
                sessionFractions.append(splitSize)
            } else {
                sessionFractions = Self.evenFractions(count: sessions.count)
            }
        } else {
            sessionFractions = Self.evenFractions(count: sessions.count)
        }
        
        activeSessionId = session.id
        normalizeFractions()
        refreshLayoutForSessionCount()
    }
    
    func removeSession(id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        
        sessions.remove(at: index)
        
        if activeSessionId == id {
            if sessions.indices.contains(index) {
                activeSessionId = sessions[index].id
            } else {
                activeSessionId = sessions.last?.id
            }
        }
        
        if index < sessionFractions.count {
            let removedFraction = sessionFractions.remove(at: index)
            if !sessionFractions.isEmpty {
                let target = min(max(0, index - 1), sessionFractions.count - 1)
                if removedFraction.isFinite, removedFraction > 0 {
                    sessionFractions[target] += removedFraction
                }
            }
        }
        
        normalizeFractions()
        refreshLayoutForSessionCount()
    }
    
    func focusSession(_ sessionId: UUID) {
        if sessions.contains(where: { $0.id == sessionId }) {
            activeSessionId = sessionId
        }
    }
    
    func setPreferredSplitLayout(vertical: Bool) {
        preferredSplitLayout = vertical ? .verticalSplit : .horizontalSplit
    }
    
    private func normalizeFractions() {
        let count = sessions.count
        guard count > 0 else {
            sessionFractions = []
            return
        }
        
        guard sessionFractions.count == count else {
            sessionFractions = Self.evenFractions(count: count)
            return
        }
        
        let sanitized = sessionFractions.map { value -> CGFloat in
            guard value.isFinite, value > 0 else { return 0.01 }
            return max(0.01, value)
        }
        let total = sanitized.reduce(CGFloat.zero, +)
        guard total.isFinite, total > 0 else {
            sessionFractions = Self.evenFractions(count: count)
            return
        }
        
        sessionFractions = sanitized.map { $0 / total }
    }
    
    private func refreshLayoutForSessionCount() {
        switch sessions.count {
        case 0, 1:
            layout = .single
        case 2:
            if layout == .single || layout == .grid {
                layout = preferredSplitLayout
            }
        default:
            layout = .grid
        }
    }
    
    private static func evenFractions(count: Int) -> [CGFloat] {
        guard count > 0 else { return [] }
        let value = 1.0 / CGFloat(count)
        return Array(repeating: value, count: count)
    }
}

enum PaneLayoutType: String, Codable, CaseIterable {
    case single
    case horizontalSplit
    case verticalSplit
    case grid
}
