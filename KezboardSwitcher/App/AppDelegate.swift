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
    private lazy var statusMenu: NSMenu = {
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open Configuration", action: #selector(openConfiguration), keyEquivalent: ",")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        return menu
    }()
    var openConfigWindow: (() -> Void)?
    var isFirstLaunch: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(named: "MenuBarIcon")
        }

        // Monitor clicks on the status item
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self,
                  let button = self.statusItem?.button,
                  event.window == button.window else {
                return event
            }
            if event.type == .rightMouseDown {
                self.showMenu()
            } else {
                self.openConfiguration()
            }
            return nil
        }

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

    private func showMenu() {
        guard let statusItem else { return }
        statusItem.menu = statusMenu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openConfiguration() {
        openConfigWindow?()
        NSApp.activate(ignoringOtherApps: true)
    }
}
