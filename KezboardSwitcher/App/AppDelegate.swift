//
//  AppDelegate.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 28.07.25.
//

import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    var openConfigWindow: (() -> Void)?
    var isFirstLaunch: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KezboardSwitcher")
        }

        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open Configuration", action: #selector(openConfiguration), keyEquivalent: ",")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu

        // Hide the window on launch unless this is the first launch (no config exists)
        if !isFirstLaunch {
            DispatchQueue.main.async {
                for window in NSApp.windows {
                    window.close()
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    @objc private func openConfiguration() {
        openConfigWindow?()
        NSApp.activate(ignoringOtherApps: true)
    }
}
