// Pane/PaneLayout.swift
// Defines the layout container for multiple terminal panes.

import SwiftUI

struct PaneLayout: View {
    @ObservedObject var tab: TabModel
    @Binding var showSettings: Bool
    @Binding var showCommandPalette: Bool
    
    var body: some View {
        Group {
            switch tab.layout {
            case .single:
                if let session = tab.sessions.first {
                    TerminalView(session: session, tab: tab, showSettings: $showSettings, showCommandPalette: $showCommandPalette)
                }
            case .horizontalSplit:
                ResizableSplitStack(axis: .horizontal, data: tab.sessions, fractions: $tab.sessionFractions) { session in
                    TerminalView(session: session, tab: tab, showSettings: $showSettings, showCommandPalette: $showCommandPalette)
                }
            case .verticalSplit:
                ResizableSplitStack(axis: .vertical, data: tab.sessions, fractions: $tab.sessionFractions) { session in
                    TerminalView(session: session, tab: tab, showSettings: $showSettings, showCommandPalette: $showCommandPalette)
                }
            case .grid:
                // Simple 2x2 grid for now if multiple sessions exist
                let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 2)
                LazyVGrid(columns: columns, spacing: 1) {
                    ForEach(tab.sessions) { session in
                        TerminalView(session: session, tab: tab, showSettings: $showSettings, showCommandPalette: $showCommandPalette)
                    }
                }
            }
        }
    }
}
