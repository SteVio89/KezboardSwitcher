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
        case .onboarding, .needsPermission:
            OnboardingWizardView()
                .frame(minWidth: 560, minHeight: 500)
        case .ready:
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    KeyboardListView()
                        .frame(minWidth: 200, idealWidth: 220)
                    Divider()
                    DetailPanel()
                        .frame(minWidth: 300, idealWidth: 360)
                }
                Divider()
                DeactivateBar()
            }
            .frame(minWidth: 560, minHeight: 400)
        case .error(let message):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                Text("Error")
                    .font(.title2)
                Text("KezboardSwitcher could not start. This is usually caused by a missing Input Monitoring permission.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 350)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                HStack(spacing: 12) {
                    Button("Open System Settings") {
                        viewModel.openSystemSettings()
                    }
                    Button("Retry") {
                        Task {
                            await viewModel.initialize()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(minWidth: 400, minHeight: 300)
        }
    }
}

// MARK: - Deactivate Bar

private struct DeactivateBar: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var showConfirmation = false
    @State private var isDeactivating = false
    @State private var errorMessage: String?

    var body: some View {
        HStack {
            Spacer()
            Button(role: .destructive) {
                showConfirmation = true
            } label: {
                if isDeactivating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Deactivate License")
                }
            }
            .disabled(isDeactivating)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .alert("Deactivate License?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Deactivate", role: .destructive) {
                deactivate()
            }
        } message: {
            Text("This will remove the license from this device. You will need to re-enter your license key to use the app again.")
        }
        .alert("Deactivation Failed", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
    }

    private func deactivate() {
        isDeactivating = true
        Task {
            do {
                try await viewModel.deactivateLicense()
            } catch {
                errorMessage = error.localizedDescription
            }
            isDeactivating = false
        }
    }
}

// MARK: - Detail Panel with Tab Picker

private struct DetailPanel: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            Picker("View", selection: $viewModel.selectedTab) {
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
