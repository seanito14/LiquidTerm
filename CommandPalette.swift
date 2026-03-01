// CommandPalette.swift
// A searchable overlay for executing terminal commands and application actions.

import SwiftUI

struct CommandPalette: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @EnvironmentObject var windowManager: WindowManager
    @EnvironmentObject var settings: SettingsStore
    
    let commands = [
        CommandItem(name: "New Tab", icon: "plus.square", action: "new_tab"),
        CommandItem(name: "Split Vertical", icon: "square.split.2x1", action: "split_v"),
        CommandItem(name: "Split Horizontal", icon: "square.split.1x2", action: "split_h"),
        CommandItem(name: "Toggle Settings", icon: "gearshape", action: "settings"),
        CommandItem(name: "Close Tab", icon: "xmark.square", action: "close_tab")
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
                                Text("⌘P")
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
        case "new_tab":
            windowManager.createNewTab()
        case "split_v":
            windowManager.splitActiveTab(vertical: true)
        case "split_h":
            windowManager.splitActiveTab(vertical: false)
        case "close_tab":
            if let activeTabId = windowManager.activeTabId {
                windowManager.closeTab(id: activeTabId)
            }
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
}
