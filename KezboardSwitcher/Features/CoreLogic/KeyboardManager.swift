//
//  IOHidManager.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 28.07.25.
//

import Foundation
import IOKit.hid
import IOKit.hidsystem
import Carbon
import os.log

enum KeyboardManagerError: LocalizedError {
    case creationFailed
    case openFailed(result: Int32)

    var errorDescription: String? {
        switch self {
        case .creationFailed:
            return "Failed to create HidManager."
        case .openFailed(result: let result):
            return "Failed to open HidManager with result \(result)."
        }
    }
}

private func globalHidInputCallback(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, value: IOHIDValue) {

    guard let context = context else {
        return
    }
    let keyboardManager = Unmanaged<KeyboardManager>.fromOpaque(context).takeUnretainedValue()
    keyboardManager.handleHidInputEvent(value: value)
}

@MainActor
class KeyboardManager {
    private let logger: Logger
    private var iohidManager: IOHIDManager?
    private var isOpen: Bool = false
    var lastKeyboard: Keyboard = Keyboard(name: "", status: .new)
    var lastKeyboardName: String { lastKeyboard.name }
    private var managedKeyboards: [Keyboard]
    private let layoutDetector: LayoutDetector
    var onKeyboardSwitch: ((Keyboard) -> Void)?
    private(set) var hasReceivedEvents = false

    init(managedKeyboards: [Keyboard] = [], layoutDetector: LayoutDetector = LayoutDetector()) throws {
        self.logger = Logger(subsystem: "de.stevio.KezboardSwitcher", category: "KeyboardManager")
        self.layoutDetector = layoutDetector
        self.managedKeyboards = managedKeyboards.filter {
            $0.status == .configured && !$0.layoutInfo.layoutId.isEmpty
        }
        try createManager()
        logger.debug("KeyboardManager initialized")

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(iohidManager!, globalHidInputCallback, context)
        logger.debug("HID callback registered")
    }

    deinit {
        guard let hidManager = iohidManager else { return }
        IOHIDManagerUnscheduleFromRunLoop(hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func stop(){
        guard let hidManager = iohidManager, isOpen else {
            logger.debug("IOHIDManager already stopped")
            return
        }

        IOHIDManagerUnscheduleFromRunLoop(hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        IOHIDManagerClose(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))

        iohidManager = nil
        isOpen = false

        logger.debug("IOHIDManager cleanup completed")
    }

    func fetchConnectedKeyboards() -> [Keyboard] {
        guard let hidManager = iohidManager, isOpen else {
            logger.error("Try to fetch keyboards while IOHIDManager is not active")
            return []
        }
        let deviceSet = IOHIDManagerCopyDevices(hidManager)
        guard let devices = deviceSet else {
            logger.debug("No devices found")
            return []
        }
        let deviceCount = CFSetGetCount(devices)
        guard deviceCount > 0 else {
            logger.debug("No devices found")
            return []
        }
        logger.debug("Found devices: \(deviceCount)")
        let deviceRefs = getDevicesArray(from: devices, count: deviceCount)

        let keyboardNames = deviceRefs.compactMap { deviceRef in getKeyboardName(from: deviceRef)}

        return keyboardNames.map { name in  Keyboard(name: name, status: .new)}
    }

    func setManagedKeyboards(_ keyboards: [Keyboard]) {
        logger.debug("Setting keyboards: \(keyboards)")

        self.managedKeyboards = keyboards.filter {
            $0.status == .configured && !$0.layoutInfo.layoutId.isEmpty
        }

        logger.debug("ManagedKeyboards updated")
    }

    /// Checks if Input Monitoring permission is currently granted.
    nonisolated static func hasInputMonitoringPermission() -> Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    /// Triggers the system permission dialog for Input Monitoring.
    /// Returns true if access was granted immediately.
    @discardableResult
    nonisolated static func requestInputMonitoringPermission() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    /// Ground truth test: actually opens an IOHIDManager to verify permission.
    /// More reliable than IOHIDCheckAccess after system-initiated restarts.
    nonisolated static func tryOpenHIDManager() -> Bool {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        guard CFGetTypeID(manager) == IOHIDManagerGetTypeID() else { return false }

        let matchingDict: [String: Any] = [
            kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keyboard
        ]
        IOHIDManagerSetDeviceMatching(manager, matchingDict as CFDictionary)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        if result == kIOReturnSuccess {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return true
        }
        return false
    }

    private func createManager() throws {
        let hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        if CFGetTypeID(hidManager) != IOHIDManagerGetTypeID() {
            throw KeyboardManagerError.creationFailed
        }
        self.iohidManager = hidManager

        let matchingDict = createKeyboardMatchingDictionary()

        IOHIDManagerSetDeviceMatching(hidManager, matchingDict)

        IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        let result = IOHIDManagerOpen(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            stop()
            throw KeyboardManagerError.openFailed(result: result)
        }
        self.isOpen = true
    }

    private func createKeyboardMatchingDictionary() -> CFDictionary {
        let usagePage = kHIDPage_GenericDesktop
        let usage = kHIDUsage_GD_Keyboard

        let matchingDict: [String: Any] = [
            kIOHIDDeviceUsagePageKey: usagePage,
            kIOHIDDeviceUsageKey: usage,
        ]

        return matchingDict as CFDictionary
    }

    private func getDevicesArray(from devicesSet: CFSet, count: CFIndex) -> [IOHIDDevice] {
        let buffer = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: count)
        defer { buffer.deallocate() }

        CFSetGetValues(devicesSet, buffer)

        var devices: [IOHIDDevice] = []
        for i in 0..<count {
            if let devicePointer = buffer[i] {
                let device = Unmanaged<IOHIDDevice>.fromOpaque(devicePointer).takeUnretainedValue()
                devices.append(device)
            }
        }

        return devices
    }

    private func getKeyboardName(from device: IOHIDDevice) -> String? {
        guard let keyboardNameRef = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) else {
            return nil
        }
        guard CFGetTypeID(keyboardNameRef) == CFStringGetTypeID() else {
            return nil
        }
        return keyboardNameRef as? String
    }

    nonisolated internal func handleHidInputEvent(value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)

        if usagePage == 0x07 {
            let intValue = IOHIDValueGetIntegerValue(value)
            if intValue == 0 { return }

            let device = IOHIDElementGetDevice(element)
            Task { @MainActor [self] in
                if !hasReceivedEvents {
                    hasReceivedEvents = true
                    logger.info("First HID event received — event delivery is working")
                }
                detectActiveKeyboard(device: device)
            }
        }
    }

    private func detectActiveKeyboard(device: IOHIDDevice) {
        guard let keyboardName = getKeyboardName(from: device) else {
            return
        }

        let isSameKeyboard = keyboardName == lastKeyboard.name
        if isSameKeyboard {
            // Same keyboard — but verify the layout is correct (could be wrong after app restart)
            guard let managed = managedKeyboards.first(where: { $0.name == keyboardName }),
                  layoutDetector.currentLayoutId() != managed.layoutInfo.layoutId else {
                return
            }
            logger.info("Layout mismatch for \(keyboardName) — correcting to \(managed.layoutInfo.layoutName)")
            layoutDetector.switchToLayout(layoutId: managed.layoutInfo.layoutId)
            return
        }

        logger.debug("Keyboard detected: \(keyboardName)")

        for keyboard in managedKeyboards {
            if keyboard.name == keyboardName {
                logger.debug("Switching layout to \(keyboard.layoutInfo.layoutName) for keyboard \(keyboardName)")
                layoutDetector.switchToLayout(layoutId: keyboard.layoutInfo.layoutId)
                lastKeyboard = keyboard
                onKeyboardSwitch?(keyboard)
                return
            }
        }

        // Track unmanaged keyboard to avoid repeated lookups on every keypress
        logger.debug("Keyboard \(keyboardName) not in managed list (\(self.managedKeyboards.count) managed)")
        lastKeyboard = Keyboard(name: keyboardName, status: .new)
    }
}
