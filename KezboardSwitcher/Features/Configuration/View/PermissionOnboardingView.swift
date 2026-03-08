//
//  PermissionOnboardingView.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 07.03.26.
//

import SwiftUI

struct PermissionOnboardingView: View {
    @Environment(AppViewModel.self) private var viewModel

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

            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                await viewModel.initialize()
            }
        }
    }
}
