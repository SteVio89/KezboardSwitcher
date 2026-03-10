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
    @State private var layoutPendingEnable: LayoutInfo?

    private var enabledLayouts: [LayoutInfo] {
        viewModel.layouts.filter(\.isEnabled)
    }

    private var installableLayouts: [LayoutInfo] {
        viewModel.layouts.filter { !$0.isEnabled }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

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
                            VStack(alignment: .leading, spacing: 16) {
                                LazyVGrid(columns: columns, spacing: 8) {
                                    ForEach(enabledLayouts, id: \.layoutId) { layout in
                                        LayoutCard(
                                            layout: layout,
                                            isSelected: keyboard.layoutInfo.layoutId == layout.layoutId,
                                            isInstallable: false
                                        ) {
                                            viewModel.assignLayout(layout, to: keyboard)
                                        }
                                    }
                                }

                                if !installableLayouts.isEmpty {
                                    Text("Available Layouts")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 4)

                                    LazyVGrid(columns: columns, spacing: 8) {
                                        ForEach(installableLayouts, id: \.layoutId) { layout in
                                            LayoutCard(
                                                layout: layout,
                                                isSelected: false,
                                                isInstallable: true
                                            ) {
                                                layoutPendingEnable = layout
                                            }
                                        }
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
        .alert("Add Layout?", isPresented: Binding(
            get: { layoutPendingEnable != nil },
            set: { if !$0 { layoutPendingEnable = nil } }
        )) {
            Button("Cancel", role: .cancel) { layoutPendingEnable = nil }
            Button("Add") {
                if let layout = layoutPendingEnable, let keyboard = viewModel.selectedKeyboard {
                    viewModel.enableLayout(layout)
                    viewModel.assignLayout(layout, to: keyboard)
                    layoutPendingEnable = nil
                }
            }
        } message: {
            Text("\"\(layoutPendingEnable?.layoutName ?? "")\" will be added to your system input sources. Continue?")
        }
    }
}

// MARK: - Layout Card

private struct LayoutCard: View {
    let layout: LayoutInfo
    let isSelected: Bool
    let isInstallable: Bool
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
                } else if isInstallable {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
            .cardStyle(isSelected: isSelected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
