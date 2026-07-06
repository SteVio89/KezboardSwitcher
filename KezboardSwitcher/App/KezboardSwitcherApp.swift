//
//  KezboardSwitcherApp.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 28.07.25.
//

import SwiftUI

@main
struct KezboardSwitcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var viewModel = AppViewModel()

    @Environment(\.openWindow) private var openWindow

    init() {
        // Single source of truth: the same onboardingCompleted flag that
        // AppViewModel.initialize() routes on also decides window visibility,
        // so the launch window can never desync from the onboarding gate.
        appDelegate.isFirstLaunch = !UserDefaults.standard.bool(forKey: AppViewModel.onboardingCompletedKey)
    }

    var body: some Scene {
        Window("KezboardSwitcher", id: "config") {
            ContentView()
                .environment(viewModel)
                .task {
                    appDelegate.openConfigWindow = { [openWindow] in
                        openWindow(id: "config")
                    }
                    appDelegate.onTogglePause = { [viewModel] in
                        viewModel.isPaused.toggle()
                    }
                    appDelegate.isPausedProvider = { [viewModel] in
                        viewModel.isPaused
                    }
                    // Use unstructured Task so initialization completes
                    // even if the window is closed immediately on launch
                    if viewModel.keyboardManager == nil {
                        Task { @MainActor [viewModel] in
                            await viewModel.initialize()
                        }
                    }
                }
        }
    }
}
