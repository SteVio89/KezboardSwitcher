//
//  OnboardingWizardView.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 09.03.26.
//

import SwiftUI

// MARK: - Step Definition

private enum OnboardingStep: Int, CaseIterable {
    case welcome
    case privacy
    case permission
    case license

    var isBlockingStep: Bool {
        switch self {
        case .permission, .license: true
        default: false
        }
    }
}

// MARK: - Wizard View

struct OnboardingWizardView: View {
    @Environment(AppViewModel.self) private var viewModel

    @State private var step: OnboardingStep = .welcome
    @State private var direction: Int = 1 // 1 = forward, -1 = back
    @State private var permissionGranted = false

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            StepIndicatorView(
                steps: OnboardingStep.allCases,
                current: step
            )
            .padding(.top, 24)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 32)

            // Step content
            ZStack {
                stepContent(for: step)
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: direction > 0 ? .trailing : .leading),
                        removal: .move(edge: direction > 0 ? .leading : .trailing)
                    ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            Divider()
                .padding(.horizontal, 32)

            // Navigation bar
            navigationBar
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private func stepContent(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeStep()
        case .privacy:
            PrivacyStep()
        case .permission:
            PermissionStep(permissionGranted: $permissionGranted)
        case .license:
            LicenseStep()
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            if step != .welcome && step != .license {
                Button {
                    if let prev = OnboardingStep(rawValue: step.rawValue - 1) {
                        navigate(to: prev)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if step == .license {
                // License step has its own action — no "Continue" button
                EmptyView()
            } else if step == .permission {
                Button("Continue") {
                    // Mark onboarding complete before license step
                    // so activateLicense → initialize() skips onboarding
                    viewModel.completeOnboarding()
                    navigate(to: .license)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!permissionGranted)
            } else {
                Button("Continue") {
                    if let next = OnboardingStep(rawValue: step.rawValue + 1) {
                        navigate(to: next)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func navigate(to target: OnboardingStep) {
        withAnimation(.easeInOut(duration: 0.3)) {
            direction = target.rawValue > step.rawValue ? 1 : -1
            step = target
        }
    }
}

// MARK: - Step Indicator

private struct StepIndicatorView<Step: RawRepresentable & CaseIterable & Equatable>: View
    where Step.RawValue == Int, Step.AllCases: RandomAccessCollection {

    let steps: Step.AllCases
    let current: Step

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                if index > 0 {
                    // Connector line
                    Rectangle()
                        .fill(index <= current.rawValue ? Theme.accentBlue : Color.secondary.opacity(0.25))
                        .frame(height: 2)
                        .frame(maxWidth: 40)
                }

                // Dot
                Circle()
                    .fill(step == current ? Theme.accentBlue :
                          index < current.rawValue ? Theme.accentBlue.opacity(0.7) :
                          Color.secondary.opacity(0.25))
                    .frame(width: step == current ? 12 : 8, height: step == current ? 12 : 8)
                    .overlay {
                        if index < current.rawValue {
                            Image(systemName: "checkmark")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: current)
            }
        }
    }
}

// MARK: - Welcome Step

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "keyboard.fill")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.skyBlue, Theme.accentBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Welcome to KezboardSwitcher")
                .font(.title.bold())

            Text("Automatically switch your keyboard layout when you switch between physical keyboards.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 380)

            Text("Let's get you set up in just a few steps.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 380)

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Privacy Step

private struct PrivacyStep: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Your Privacy Matters")
                .font(.title2.bold())

            Text("KezboardSwitcher needs Input Monitoring permission — here's exactly what that means:")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)

            VStack(spacing: 12) {
                PrivacyBullet(
                    symbol: "keyboard.badge.eye",
                    title: "We only detect which keyboard is active",
                    subtitle: "We identify the physical keyboard device — not what you type on it."
                )
                PrivacyBullet(
                    symbol: "eye.slash",
                    title: "No keystrokes are recorded or transmitted",
                    subtitle: "Your typing content is never captured, stored, or sent anywhere."
                )
                PrivacyBullet(
                    symbol: "internaldrive",
                    title: "All data stays on your device",
                    subtitle: "Configuration and statistics are stored locally and never leave your Mac."
                )
                PrivacyBullet(
                    symbol: "wifi.slash",
                    title: "No internet access after activation",
                    subtitle: "Once your license is activated, the app works fully offline."
                )
            }
            .frame(maxWidth: 440)

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

private struct PrivacyBullet: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(Theme.accentBlue)
                .frame(width: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Permission Step

private struct PermissionStep: View {
    @Binding var permissionGranted: Bool

    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: permissionGranted ? "checkmark.shield.fill" : "lock.shield")
                .font(.system(size: 64))
                .foregroundStyle(permissionGranted ? .green : .orange)
                .contentTransition(.symbolEffect(.replace))

            Text("Grant Input Monitoring")
                .font(.title2.bold())

            if permissionGranted {
                Text("Permission granted — you're all set to continue.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 380)

                Label("Permission granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout.bold())
            } else {
                Text("macOS will ask you to allow Input Monitoring for KezboardSwitcher. Click \"Allow\" to continue.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 380)

                Button("Grant Permission") {
                    requestPermission()
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .onAppear {
            // Check if already granted (e.g. from a previous run)
            if KeyboardManager.hasInputMonitoringPermission() {
                permissionGranted = true
            }
        }
        .onDisappear {
            pollTask?.cancel()
        }
    }

    private func requestPermission() {
        KeyboardManager.requestInputMonitoringPermission()

        // The system dialog doesn't trigger any app notification when the
        // user clicks Allow, so we poll until permission is granted.
        pollTask?.cancel()
        pollTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if KeyboardManager.hasInputMonitoringPermission() {
                    permissionGranted = true
                    return
                }
            }
        }
    }
}

// MARK: - License Step

private struct LicenseStep: View {
    var body: some View {
        LicenseActivationView()
    }
}
