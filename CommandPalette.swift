// CommandPalette.swift
// A searchable overlay for executing terminal commands and application actions.

import SwiftUI

struct CommandPalette: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @EnvironmentObject var windowManager: WindowManager
    @EnvironmentObject var settings: SettingsStore
    
    let commands = [
        CommandItem(name: "Split Vertical", icon: "square.split.2x1", action: "split_v", shortcut: "⌘D"),
        CommandItem(name: "Split Horizontal", icon: "square.split.1x2", action: "split_h", shortcut: "⇧⌘D"),
        CommandItem(name: "Toggle Settings", icon: "gearshape", action: "settings", shortcut: "⌘,"),
        CommandItem(name: "Close Pane or Tab", icon: "xmark.square", action: "close_pane", shortcut: "⌘W")
    ]
    
    var filteredCommands: [CommandItem] {
        if searchText.isEmpty {
            return commands
        }
        return commands.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Type a command...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($isSearchFocused)
                    .onSubmit {
                        if let first = filteredCommands.first {
                            execute(first)
                        }
                    }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Command list
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(filteredCommands) { command in
                        Button(action: {
                            execute(command)
                        }) {
                            HStack {
                                Image(systemName: command.icon)
                                    .frame(width: 24)
                                Text(command.name)
                                Spacer()
                                Text(command.shortcut)
                                    .font(.system(size: 10, weight: .light))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                            .background(Color.white.opacity(0.02))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 300)
        }
        .onAppear {
            DispatchQueue.main.async {
                isSearchFocused = true
            }
        }
        .frame(width: 400)
        .background(
            VisualEffectView(material: .selection, blendingMode: .withinWindow)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(radius: 20)
    }
    
    private func execute(_ command: CommandItem) {
        switch command.action {
        case "split_v":
            windowManager.splitActiveTab(vertical: true)
        case "split_h":
            windowManager.splitActiveTab(vertical: false)
        case "settings":
            NotificationCenter.default.post(name: .toggleSettings, object: nil)
        case "close_pane":
            NotificationCenter.default.post(name: .closePane, object: nil)
        default:
            break
        }
        isPresented = false
    }
}

struct CommandItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let action: String
    let shortcut: String
}
