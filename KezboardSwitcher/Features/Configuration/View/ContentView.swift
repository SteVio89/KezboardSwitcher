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
        case .unlicensed:
            LicenseActivationView()
        case .needsPermission:
            PermissionOnboardingView()
        case .ready:
            HStack(spacing: 0) {
                KeyboardListView()
                    .frame(minWidth: 200, idealWidth: 220)
                Divider()
                DetailPanel()
                    .frame(minWidth: 300, idealWidth: 360)
            }
            .frame(minWidth: 560, minHeight: 400)
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

// MARK: - Detail Panel with Tab Picker

private struct DetailPanel: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            Picker("", selection: $viewModel.selectedTab) {
                Label("Configuration", systemImage: "keyboard")
                    .tag(DetailTab.configuration)
                Label("Statistics", systemImage: "chart.bar.fill")
                    .tag(DetailTab.statistics)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            switch viewModel.selectedTab {
            case .configuration:
                LayoutSelectorView()
            case .statistics:
                StatisticsView()
                    .onAppear {
                        viewModel.refreshStatistics()
                    }
            }
        }
    }
}
