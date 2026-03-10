//
//  LayoutSelectorView.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 07.03.26.
//

import SwiftUI

struct LayoutSelectorView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var showRemoveConfirmation = false

    var body: some View {
        VStack {
            if let keyboard = viewModel.selectedKeyboard {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(keyboard.name)
                                .font(.title3.bold())
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Theme.statusColor(for: keyboard.status))
                                    .frame(width: 8, height: 8)
                                Text(keyboard.status.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button(keyboard.status == .ignored ? "Unignore" : "Ignore") {
                            viewModel.toggleIgnore(keyboard)
                        }
                        .controlSize(.small)
                        Button(role: .destructive) {
                            showRemoveConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .controlSize(.small)
                    }

                    if keyboard.status != .ignored {
                        Divider()
                        Text("Assign Layout")
                            .font(.headline)

                        ScrollView {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8)
                            ], spacing: 8) {
                                ForEach(viewModel.layouts, id: \.layoutId) { layout in
                                    LayoutCard(
                                        layout: layout,
                                        isSelected: keyboard.layoutInfo.layoutId == layout.layoutId
                                    ) {
                                        viewModel.assignLayout(layout, to: keyboard)
                                    }
                                }
                            }
                        }
                        Divider()
                        HStack {
                            if let feedback = viewModel.saveFeedback {
                                Text(feedback)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .transition(.opacity)
                            }
                            Spacer()
                            Button("Save") {
                                viewModel.saveConfig()
                            }
                            .keyboardShortcut("s")
                            .padding()
                        }
                    } else {
                        Spacer()
                        Text("This keyboard is ignored")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                        Spacer()
                    }
                }
                .padding()
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "keyboard")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("Select a keyboard")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .alert("Remove Keyboard?", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let keyboard = viewModel.selectedKeyboard {
                    viewModel.removeKeyboard(keyboard)
                }
            }
        } message: {
            Text("Remove \"\(viewModel.selectedKeyboard?.name ?? "")\" from configuration? It will reappear as a new keyboard if still connected.")
        }
    }
}

// MARK: - Layout Card

private struct LayoutCard: View {
    let layout: LayoutInfo
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(layout.layoutName)
                    .font(.callout)
                    .lineLimit(1)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accentBlue)
                        .font(.callout)
                }
            }
            .cardStyle(isSelected: isSelected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
