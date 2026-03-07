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
        List(viewModel.keyboards, selection: $viewModel.selectedKeyboard) { keyboard in
            HStack {
                Image(systemName: "keyboard")
                    .foregroundStyle(statusColor(for: keyboard.status))
                VStack(alignment: .leading) {
                    Text(keyboard.name)
                        .lineLimit(1)
                    Text(keyboard.status.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge(for: keyboard.status)
            }
            .tag(keyboard)
            .padding(.vertical, 2)
        }
        .listStyle(.sidebar)
    }

    private func statusColor(for status: KeyboardStatus) -> Color {
        switch status {
        case .new: .blue
        case .configured: .green
        case .ignored: .gray
        }
    }

    private func statusBadge(for status: KeyboardStatus) -> some View {
        Circle()
            .fill(statusColor(for: status))
            .frame(width: 8, height: 8)
    }
}
