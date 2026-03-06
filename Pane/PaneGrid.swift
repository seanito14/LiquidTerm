// Pane/PaneGrid.swift
// Manages the grid of terminal panes with focus indication.

import SwiftUI

struct PaneGrid: View {
    @ObservedObject var tab: TabModel
    @Binding var showSettings: Bool
    @Binding var showCommandPalette: Bool
    
    var body: some View {
        PaneLayout(tab: tab, showSettings: $showSettings, showCommandPalette: $showCommandPalette)
    }
}
