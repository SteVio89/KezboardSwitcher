//
//  AppViewModel.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 07.03.26.
//

import AppKit
import OSLog
import UserNotifications

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
    case troubleshoot
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
    // In-memory only by design: pause never survives an app restart.
    var isPaused = false {
        didSet { keyboardManager?.isPaused = isPaused }
    }

    // Troubleshoot
    var logEntries: [LogEntry] = []

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

    /// Returns whether a verified license is already stored on this device.
    ///
    /// - Returns: `true` if a stored license exists and passes verification.
    func hasStoredLicense() -> Bool {
        licenseService.load() != nil
    }

    /// Marks onboarding as completed and requests notification authorization.
    /// Requesting here (instead of lazily when a failure occurs) ensures the
    /// permission dialog appears in a context the user understands.
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { [logger] granted, error in
            if let error {
                logger.error("Notification authorization request failed: \(error.localizedDescription)")
            } else {
                logger.debug("Notification authorization granted: \(granted)")
            }
        }
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
            let manager = try await createManagerWithRetry(configKeyboards: configKeyboards)
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
            // A recreated manager must inherit the current pause state
            manager.isPaused = isPaused

            let detected = manager.fetchConnectedKeyboards()

            // Restore persisted last keyboard to avoid false switch count on app restart
            if let persistedName = UserDefaults.standard.string(forKey: Self.lastKeyboardKey), !persistedName.isEmpty {
                manager.lastKeyboard = Keyboard(name: persistedName, status: .new)
                // Show the active-keyboard header immediately, but only if that keyboard is still connected
                if detected.contains(where: { $0.name == persistedName }) {
                    activeKeyboardName = persistedName
                }
            }
            keyboards = Self.merge(config: configKeyboards, detected: detected)

            layouts = layoutDetector.getAllLayouts()

            manager.setManagedKeyboards(keyboards)

            refreshStatistics()

            appState = .ready
            logger.debug("Initialized with \(self.keyboards.count) keyboard(s), \(self.layouts.count) layout(s)")
            startEventWatchdog(manager: manager)
        } catch let error as KeyboardManagerError {
            switch error {
            case .openFailed, .creationFailed:
                appState = .needsPermission
            }
            logger.error("Failed to initialize: \(error.localizedDescription)")
            sendFailureNotification()
        } catch {
            appState = .error(error.localizedDescription)
            logger.error("Failed to initialize: \(error.localizedDescription)")
        }
    }

    // MARK: - Retry & Notification

    private static let maxRetries = 5
    private static let retryDelay: Duration = .seconds(2)

    private func createManagerWithRetry(configKeyboards: [Keyboard]) async throws -> KeyboardManager {
        var lastError: Error?
        for attempt in 1...Self.maxRetries {
            do {
                let manager = try KeyboardManager(managedKeyboards: configKeyboards, layoutDetector: layoutDetector)
                if attempt > 1 {
                    logger.info("HID manager opened on attempt \(attempt)")
                }
                return manager
            } catch {
                lastError = error
                let hasPermission = KeyboardManager.hasInputMonitoringPermission()
                logger.warning("HID open attempt \(attempt)/\(Self.maxRetries) failed (permission granted: \(hasPermission))")
                if !hasPermission {
                    // Permission genuinely missing — no point retrying
                    throw error
                }
                if attempt < Self.maxRetries {
                    try? await Task.sleep(for: Self.retryDelay)
                }
            }
        }
        throw lastError!
    }

    private static let watchdogWindowSeconds: Double = 30

    private func startEventWatchdog(manager: KeyboardManager) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.watchdogWindowSeconds))
            guard let self, self.keyboardManager === manager else { return }
            if manager.hasReceivedEvents { return }
            // Distinguish "user simply hasn't typed" from a broken TCC state:
            // CGEventSource sees system-wide keydowns without needing Input Monitoring.
            let sinceLastKeyDown = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .keyDown)
            if sinceLastKeyDown > Self.watchdogWindowSeconds {
                logger.debug("No system-wide keydown within the watchdog window — rescheduling watchdog")
                startEventWatchdog(manager: manager)
            } else {
                logger.warning("System saw keydowns but no HID events reached us after \(Self.watchdogWindowSeconds)s — permission may be in a broken state")
                sendFailureNotification(
                    message: "Keyboard events are not being received. Try toggling Input Monitoring permission off and on in System Settings, then restart the app."
                )
            }
        }
    }

    private func sendFailureNotification(
        message: String = "Could not access keyboard input. Please check Input Monitoring permission in System Settings."
    ) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [logger] settings in
            guard settings.authorizationStatus == .authorized else {
                logger.warning("Cannot deliver failure notification — notifications not authorized (status: \(settings.authorizationStatus.rawValue))")
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "KezboardSwitcher"
            content.body = message
            let request = UNNotificationRequest(identifier: "hid-permission-failure", content: content, trigger: nil)
            center.add(request)
        }
    }

    nonisolated static func merge(config: [Keyboard], detected: [Keyboard]) -> [Keyboard] {
        var result = config
        // Seeded with config names and grown as we append, so duplicate HID
        // interfaces with identical product strings collapse to one entry.
        var seenNames = Set(config.map(\.name))
        for keyboard in detected where !seenNames.contains(keyboard.name) {
            seenNames.insert(keyboard.name)
            result.append(keyboard)
        }
        return result
    }

    func enableLayout(_ layout: LayoutInfo) {
        layoutDetector.enableLayout(layoutId: layout.layoutId)
        // Patch in-place to avoid race with TIS state propagation
        if let index = layouts.firstIndex(where: { $0.layoutId == layout.layoutId }) {
            layouts[index].isEnabled = true
        }
    }

    func assignLayout(_ layout: LayoutInfo, to keyboard: Keyboard) {
        guard let index = keyboards.firstIndex(where: { $0.name == keyboard.name }) else { return }
        keyboards[index].layoutInfo = layout
        keyboards[index].status = .configured
        keyboardManager?.setManagedKeyboards(keyboards)
        syncSelectedKeyboard(name: keyboard.name)
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
        syncSelectedKeyboard(name: keyboard.name)
    }

    private func syncSelectedKeyboard(name: String) {
        if selectedKeyboard?.name == name {
            selectedKeyboard = keyboards.first { $0.name == name }
        }
    }

    func removeKeyboard(_ keyboard: Keyboard) {
        keyboards.removeAll { $0.name == keyboard.name }
        if selectedKeyboard?.name == keyboard.name {
            selectedKeyboard = nil
        }
        keyboardManager?.setManagedKeyboards(keyboards)
    }

    func reloadKeyboards() {
        guard let manager = keyboardManager else { return }
        let detected = manager.fetchConnectedKeyboards()
        keyboards = Self.merge(config: keyboards, detected: detected)
        manager.setManagedKeyboards(keyboards)
        logger.debug("Reloaded keyboards: \(self.keyboards.count) total")
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

    // MARK: - Troubleshoot

    func fetchLogs() {
        Task.detached(priority: .utility) {
            do {
                let store = try OSLogStore(scope: .currentProcessIdentifier)
                let since = store.position(date: Date().addingTimeInterval(-3600))
                let predicate = NSPredicate(format: "subsystem == %@", "de.stevio.KezboardSwitcher")
                let entries = try store.getEntries(at: since, matching: predicate)
                    .compactMap { $0 as? OSLogEntryLog }
                    .map { LogEntry(date: $0.date, category: $0.category, level: $0.level, message: $0.composedMessage) }
                await MainActor.run { self.logEntries = entries }
            } catch {
                await MainActor.run {
                    self.logger.error("Failed to fetch logs: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct LogEntry: Identifiable, Equatable {
    let id: String
    let date: Date
    let category: String
    let level: OSLogEntryLog.Level
    let message: String

    init(date: Date, category: String, level: OSLogEntryLog.Level, message: String) {
        self.date = date
        self.category = category
        self.level = level
        self.message = message
        self.id = "\(date.timeIntervalSince1970)-\(category)-\(message)"
    }

    var levelLabel: String {
        switch level {
        case .debug: "DEBUG"
        case .info: "INFO"
        case .notice: "NOTICE"
        case .error: "ERROR"
        case .fault: "FAULT"
        default: "LOG"
        }
    }
}
