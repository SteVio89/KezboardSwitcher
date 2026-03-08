//
//  KeyboardListView.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 07.03.26.
//

import SwiftUI

struct KeyboardListView: View {
    @Environment(AppViewModel.self) private var viewModel

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
            }
            .listStyle(.sidebar)
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
