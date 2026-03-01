// Pane/PaneGrid.swift
// A high-level components that manages the grid of terminal panes and their focus state.

import SwiftUI

struct PaneGrid: View {
    @ObservedObject var tab: TabModel
    @Binding var showSettings: Bool
    @Binding var showCommandPalette: Bool
    
    var body: some View {
        PaneLayout(tab: tab, showSettings: $showSettings, showCommandPalette: $showCommandPalette)
            .background(Color.black.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}
