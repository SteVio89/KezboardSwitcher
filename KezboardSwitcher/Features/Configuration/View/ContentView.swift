//
//  ContentView.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 28.07.25.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        switch viewModel.appState {
        case .loading:
            ProgressView("Starting...")
                .frame(minWidth: 400, minHeight: 300)
        case .needsPermission:
            PermissionOnboardingView()
        case .ready:
            HStack(spacing: 0) {
                KeyboardListView()
                    .frame(minWidth: 200, idealWidth: 220)
                Divider()
                LayoutSelectorView()
                    .frame(minWidth: 250, idealWidth: 300)
            }
            .frame(minWidth: 500, minHeight: 350)
        case .error(let message):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                Text("Error")
                    .font(.title2)
                Text(message)
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task {
                        await viewModel.initialize()
                    }
                }
            }
            .frame(minWidth: 400, minHeight: 300)
        }
    }
}
