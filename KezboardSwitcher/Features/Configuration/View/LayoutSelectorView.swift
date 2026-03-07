//
//  LayoutSelectorView.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 07.03.26.
//

import SwiftUI

struct LayoutSelectorView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        VStack {
            if let keyboard = viewModel.selectedKeyboard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(keyboard.name)
                            .font(.title3.bold())
                        Spacer()
                        Button(keyboard.status == .ignored ? "Unignore" : "Ignore") {
                            viewModel.toggleIgnore(keyboard)
                        }
                    }

                    if keyboard.status != .ignored {
                        Divider()
                        Text("Assign Layout")
                            .font(.headline)
                        List(viewModel.layouts, id: \.layoutId) { layout in
                            HStack {
                                Text(layout.layoutName)
                                Spacer()
                                if keyboard.layoutInfo.layoutId == layout.layoutId {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.assignLayout(layout, to: keyboard)
                            }
                        }
                        .listStyle(.plain)
                    } else {
                        Spacer()
                        Text("This keyboard is ignored")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                        Spacer()
                    }
                }
                .padding()

                Divider()
                HStack {
                    Spacer()
                    Button("Save") {
                        viewModel.saveConfig()
                    }
                    .keyboardShortcut("s")
                    .padding()
                }
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "keyboard")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Select a keyboard")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }
}
