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
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/KezboardSwitcher/config.json")
        appDelegate.isFirstLaunch = !FileManager.default.fileExists(atPath: configPath.path)
    }

    var body: some Scene {
        Window("KezboardSwitcher", id: "config") {
            ContentView()
                .environment(viewModel)
                .task {
                    appDelegate.openConfigWindow = { [openWindow] in
                        openWindow(id: "config")
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
