//
//  AppDelegate.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 28.07.25.
//

import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private lazy var pauseItem: NSMenuItem = {
        let item = NSMenuItem(title: "Pause Switching", action: #selector(togglePause), keyEquivalent: "")
        item.target = self
        return item
    }()
    private lazy var statusMenu: NSMenu = {
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open Configuration", action: #selector(openConfiguration), keyEquivalent: ",")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(pauseItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        return menu
    }()
    var openConfigWindow: (() -> Void)?
    var onTogglePause: (() -> Void)?
    var isPausedProvider: (() -> Bool)?
    var isFirstLaunch: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        statusItem?.button?.image = NSImage(named: "MenuBarIcon")
        // Assigning the menu lets AppKit open it on a normal click and handle
        // highlight, positioning and accessibility natively — menu-bar managers
        // (Bartender/Ice) and assistive tools drive a real NSMenu for free.
        statusMenu.delegate = self
        statusItem?.menu = statusMenu

        // Hide the config window on launch unless onboarding is still
        // incomplete. Only the config window is closed — closing every window
        // in NSApp.windows would also tear down the private NSStatusBarWindow
        // hosting our menu-bar item, leaving the icon present but unclickable.
        if !isFirstLaunch {
            DispatchQueue.main.async {
                for window in NSApp.windows where window.title == "KezboardSwitcher" {
                    window.close()
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    /// Refresh dynamic menu state just before AppKit shows the menu.
    func menuWillOpen(_ menu: NSMenu) {
        pauseItem.state = (isPausedProvider?() ?? false) ? .on : .off
    }

    @objc private func togglePause() {
        onTogglePause?()
        // Dim the menu-bar icon while switching is paused
        statusItem?.button?.appearsDisabled = isPausedProvider?() ?? false
    }

    @objc private func openConfiguration() {
        if let openConfigWindow {
            openConfigWindow()
        } else {
            // Fallback: find the existing window by title and bring it forward
            for window in NSApp.windows where window.title == "KezboardSwitcher" {
                window.makeKeyAndOrderFront(nil)
                break
            }
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
