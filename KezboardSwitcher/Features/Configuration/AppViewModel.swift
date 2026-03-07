//
//  AppViewModel.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 07.03.26.
//

import AppKit
import os.log

enum AppState: Equatable {
    case loading
    case needsPermission
    case ready
    case error(String)
}

@Observable @MainActor
final class AppViewModel {
    var keyboards: [Keyboard] = []
    var layouts: [LayoutInfo] = []
    var selectedKeyboard: Keyboard?
    var appState: AppState = .loading

    private(set) var keyboardManager: KeyboardManager?
    private let configService: ConfigService
    private let layoutDetector: LayoutDetector
    private let logger = Logger(subsystem: "de.stevio.KezboardSwitcher", category: "AppViewModel")

    init(configService: ConfigService = ConfigService(), layoutDetector: LayoutDetector = LayoutDetector()) {
        self.configService = configService
        self.layoutDetector = layoutDetector
    }

    func initialize() {
        appState = .loading

        let configKeyboards = configService.load()

        do {
            let manager = try KeyboardManager(managedKeyboards: configKeyboards)
            manager.onKeyboardSwitch = { [weak self] keyboard in
                self?.logger.debug("Switched to keyboard: \(keyboard.name)")
            }
            self.keyboardManager = manager

            let detected = manager.fetchConnectedKeyboards()
            keyboards = Self.merge(config: configKeyboards, detected: detected)

            layouts = layoutDetector.getAvailableLayouts()

            manager.setManagedKeyboards(keyboards)

            appState = .ready
            logger.debug("Initialized with \(self.keyboards.count) keyboard(s), \(self.layouts.count) layout(s)")
        } catch let error as KeyboardManagerError {
            if case .openFailed = error {
                appState = .needsPermission
            } else {
                appState = .error(error.localizedDescription)
            }
            logger.error("Failed to initialize: \(error.localizedDescription)")
        } catch {
            appState = .error(error.localizedDescription)
            logger.error("Failed to initialize: \(error.localizedDescription)")
        }
    }

    nonisolated static func merge(config: [Keyboard], detected: [Keyboard]) -> [Keyboard] {
        var result = config
        let configNames = Set(config.map(\.name))
        for keyboard in detected where !configNames.contains(keyboard.name) {
            result.append(keyboard)
        }
        return result
    }

    func assignLayout(_ layout: LayoutInfo, to keyboard: Keyboard) {
        guard let index = keyboards.firstIndex(where: { $0.name == keyboard.name }) else { return }
        keyboards[index].layoutInfo = layout
        keyboards[index].status = .configured
        keyboardManager?.setManagedKeyboards(keyboards)
    }

    func toggleIgnore(_ keyboard: Keyboard) {
        guard let index = keyboards.firstIndex(where: { $0.name == keyboard.name }) else { return }
        if keyboards[index].status == .ignored {
            keyboards[index].status = .new
            keyboards[index].layoutInfo = LayoutInfo()
        } else {
            keyboards[index].status = .ignored
            keyboards[index].layoutInfo = LayoutInfo()
        }
        keyboardManager?.setManagedKeyboards(keyboards)
    }

    func saveConfig() {
        do {
            try configService.save(keyboards: keyboards)
            logger.debug("Config saved")
        } catch {
            logger.error("Failed to save config: \(error.localizedDescription)")
        }
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}
