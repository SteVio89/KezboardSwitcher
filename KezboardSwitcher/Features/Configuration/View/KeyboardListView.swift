//
//  KeyboardListView.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 07.03.26.
//

import SwiftUI

struct KeyboardListView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var keyboardToRemove: Keyboard?

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            // Active keyboard header
            if let active = viewModel.keyboards.first(where: { $0.name == viewModel.activeKeyboardName }) {
                ActiveKeyboardHeader(keyboard: active)
                Divider()
            }

            List(viewModel.keyboards, selection: $viewModel.selectedKeyboard) { keyboard in
                KeyboardRow(keyboard: keyboard)
                    .tag(keyboard)
                    .contextMenu {
                        Button(role: .destructive) {
                            keyboardToRemove = keyboard
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
            .listStyle(.sidebar)
            .safeAreaInset(edge: .bottom) {
                Button {
                    viewModel.reloadKeyboards()
                } label: {
                    Label("Reload Keyboards", systemImage: "arrow.clockwise")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
                .background(.bar)
                .overlay(alignment: .top) { Divider() }
            }
            .alert("Remove Keyboard?", isPresented: .init(
                get: { keyboardToRemove != nil },
                set: { if !$0 { keyboardToRemove = nil } }
            )) {
                Button("Cancel", role: .cancel) { keyboardToRemove = nil }
                Button("Remove", role: .destructive) {
                    if let keyboard = keyboardToRemove {
                        viewModel.removeKeyboard(keyboard)
                    }
                    keyboardToRemove = nil
                }
            } message: {
                Text("Remove \"\(keyboardToRemove?.name ?? "")\" from configuration? It will reappear as a new keyboard if still connected.")
            }
        }
    }
}

// MARK: - Active Keyboard Header

private struct ActiveKeyboardHeader: View {
    let keyboard: Keyboard

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "keyboard.fill")
                .font(.title3)
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Active")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Text(keyboard.name)
                    .font(.callout.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
        .background {
            LinearGradient(
                colors: [Theme.skyBlue, Theme.accentBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Keyboard Row

private struct KeyboardRow: View {
    let keyboard: Keyboard

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "keyboard")
                .foregroundStyle(Theme.statusColor(for: keyboard.status))
            VStack(alignment: .leading, spacing: 2) {
                Text(keyboard.name)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(keyboard.status.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if keyboard.status == .configured, !keyboard.layoutInfo.layoutName.isEmpty {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(keyboard.layoutInfo.layoutName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            Circle()
                .fill(Theme.statusColor(for: keyboard.status))
                .frame(width: 8, height: 8)
                .accessibilityLabel(keyboard.status.displayName)
        }
        .padding(.vertical, 2)
    }
}
