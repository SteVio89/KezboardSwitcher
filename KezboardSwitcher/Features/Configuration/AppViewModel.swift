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
    case onboarding
    case unlicensed
    case needsPermission
    case ready
    case error(String)
}

enum DetailTab: Hashable {
    case configuration
    case statistics
}

@Observable @MainActor
final class AppViewModel {
    var keyboards: [Keyboard] = []
    var layouts: [LayoutInfo] = []
    var selectedKeyboard: Keyboard?
    var appState: AppState = .loading
    var saveFeedback: String?
    var selectedTab: DetailTab = .configuration
    var activeKeyboardName: String?

    // Statistics
    var switchCountToday: Int = 0
    var totalSwitchCount: Int = 0
    var keyboardUsages: [KeyboardUsage] = []
    var dailySwitchCounts: [DailySwitchCount] = []

    private(set) var keyboardManager: KeyboardManager?
    private let configService: ConfigService
    private let layoutDetector: LayoutDetector
    private let statisticsService: StatisticsService
    private let licenseService: LicenseService
    private let logger = Logger(subsystem: "de.stevio.KezboardSwitcher", category: "AppViewModel")
    private static let lastKeyboardKey = "de.stevio.KezboardSwitcher.lastKeyboardName"
    static let onboardingCompletedKey = "onboardingCompleted"

    init(
        configService: ConfigService = ConfigService(),
        layoutDetector: LayoutDetector = LayoutDetector(),
        statisticsService: StatisticsService = StatisticsService(),
        licenseService: LicenseService = LicenseService()
    ) {
        self.configService = configService
        self.layoutDetector = layoutDetector
        self.statisticsService = statisticsService
        self.licenseService = licenseService
    }

    func activateLicense(licenseKey: String) async throws {
        let trimmed = licenseKey.trimmingCharacters(in: .whitespaces)
        _ = try await Task.detached { [licenseService] in
            try await licenseService.activate(licenseKey: trimmed)
        }.value
        await initialize()
    }

    func deactivateLicense() async throws {
        try await Task.detached { [licenseService] in
            try await licenseService.deactivate()
        }.value
        keyboardManager = nil
        keyboards = []
        appState = .unlicensed
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey)
    }

    func initialize() async {
        appState = .loading
        selectedKeyboard = nil

        if !UserDefaults.standard.bool(forKey: Self.onboardingCompletedKey) {
            appState = .onboarding
            return
        }

        let storedLicense = licenseService.load()
        guard storedLicense != nil else {
            appState = .unlicensed
            return
        }

        let configKeyboards = await Task.detached { [configService] in
            configService.load()
        }.value

        do {
            let manager = try KeyboardManager(managedKeyboards: configKeyboards, layoutDetector: layoutDetector)
            manager.onKeyboardSwitch = { [weak self] keyboard in
                self?.logger.debug("Switched to keyboard: \(keyboard.name)")
                self?.activeKeyboardName = keyboard.name
                self?.recordSwitch(keyboard)
                UserDefaults.standard.set(keyboard.name, forKey: Self.lastKeyboardKey)
                SwitchHUD.shared.show(
                    keyboardName: keyboard.name,
                    layoutName: keyboard.layoutInfo.layoutName
                )
            }
            self.keyboardManager = manager

            // Restore persisted last keyboard to avoid false switch count on app restart
            if let persistedName = UserDefaults.standard.string(forKey: Self.lastKeyboardKey), !persistedName.isEmpty {
                manager.lastKeyboard = Keyboard(name: persistedName, status: .new)
            }

            let detected = manager.fetchConnectedKeyboards()
            keyboards = Self.merge(config: configKeyboards, detected: detected)

            layouts = layoutDetector.getAvailableLayouts()

            manager.setManagedKeyboards(keyboards)

            refreshStatistics()

            appState = .ready
            logger.debug("Initialized with \(self.keyboards.count) keyboard(s), \(self.layouts.count) layout(s)")
        } catch let error as KeyboardManagerError {
            switch error {
            case .openFailed, .creationFailed:
                appState = .needsPermission
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
            saveFeedback = "Configuration saved"
            logger.debug("Config saved")
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(3))
                if self?.saveFeedback == "Configuration saved" {
                    self?.saveFeedback = nil
                }
            }
        } catch {
            saveFeedback = "Failed to save: \(error.localizedDescription)"
            logger.error("Failed to save config: \(error.localizedDescription)")
        }
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Statistics

    private func recordSwitch(_ keyboard: Keyboard) {
        statisticsService.recordSwitch(
            keyboardName: keyboard.name,
            layoutId: keyboard.layoutInfo.layoutId,
            layoutName: keyboard.layoutInfo.layoutName
        )
        refreshStatistics()
    }

    func refreshStatistics() {
        switchCountToday = statisticsService.switchCountToday()
        totalSwitchCount = statisticsService.totalSwitchCount()
        keyboardUsages = statisticsService.keyboardUsage()
        dailySwitchCounts = statisticsService.dailySwitchCounts()
    }

    func resetStatistics() {
        statisticsService.deleteAll()
        refreshStatistics()
    }
}
