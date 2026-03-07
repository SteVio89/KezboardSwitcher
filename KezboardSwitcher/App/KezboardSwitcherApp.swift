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

    var body: some Scene {
        Window("KezboardSwitcher", id: "config") {
            ContentView()
                .environment(viewModel)
                .task {
                    appDelegate.viewModel = viewModel
                    appDelegate.openConfigWindow = { [openWindow] in
                        openWindow(id: "config")
                    }
                    viewModel.initialize()
                }
        }
    }
}
