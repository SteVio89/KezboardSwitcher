//
//  PermissionOnboardingView.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 07.03.26.
//

import SwiftUI

struct PermissionOnboardingView: View {
    @Environment(AppViewModel.self) private var viewModel

    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            Text("Input Monitoring Required")
                .font(.title2.bold())

            Text("KezboardSwitcher needs Input Monitoring permission to detect which keyboard you're typing on and automatically switch layouts.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 350)

            VStack(spacing: 12) {
                Button("Open System Settings") {
                    viewModel.openSystemSettings()
                }
                .buttonStyle(.borderedProminent)

                Button("Check Again") {
                    Task {
                        await viewModel.initialize()
                    }
                }
            }

            Text("Enable KezboardSwitcher under Privacy & Security → Input Monitoring. The app resumes automatically once permission is granted.")
                .multilineTextAlignment(.center)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)

            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            startPolling()
        }
        .onDisappear {
            pollTask?.cancel()
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { @MainActor in
            // If permission already reads as granted here, the HID manager failed
            // to open despite it (broken TCC state). Only re-initialize after a
            // denied → granted transition so a stuck "granted" reading cannot
            // trigger an initialize loop; "Check Again" covers that case manually.
            var sawDenied = !KeyboardManager.hasInputMonitoringPermission()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(333))
                if !KeyboardManager.hasInputMonitoringPermission() {
                    sawDenied = true
                } else if sawDenied {
                    await viewModel.initialize()
                    return
                }
            }
        }
    }
}
