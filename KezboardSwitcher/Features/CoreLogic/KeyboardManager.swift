//
//  IOHidManager.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 28.07.25.
//

import Foundation
import IOKit.hid
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
    private(set) var lastKeyboard: Keyboard = Keyboard(name: "", status: .new)
    var lastKeyboardName: String { lastKeyboard.name }
    private var managedKeyboards: [Keyboard]
    private let layoutDetector: LayoutDetector
    var onKeyboardSwitch: ((Keyboard) -> Void)?

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
        IOHIDManagerUnscheduleFromRunLoop(hidManager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func stop(){
        guard let hidManager = iohidManager, isOpen else {
            logger.debug("IOHIDManager already stopped")
            return
        }

        IOHIDManagerUnscheduleFromRunLoop(hidManager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

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

        let managedKeyboards = keyboards.filter {
            $0.status == .configured && !$0.layoutInfo.layoutId.isEmpty
        }

        self.lastKeyboard = Keyboard(name: "", status: .new)
        self.managedKeyboards = managedKeyboards

        logger.debug("ManagedKeyboards updated")
    }

    private func createManager() throws {
        let hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        if CFGetTypeID(hidManager) != IOHIDManagerGetTypeID() {
            throw KeyboardManagerError.creationFailed
        }
        self.iohidManager = hidManager

        let matchingDict = createKeyboardMatchingDictionary()

        IOHIDManagerSetDeviceMatching(hidManager, matchingDict)

        IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

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
        return (keyboardNameRef as! CFString) as String
    }

    nonisolated internal func handleHidInputEvent(value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)

        if usagePage == 0x07 {
            let intValue = IOHIDValueGetIntegerValue(value)
            if intValue == 0 { return }

            let device = IOHIDElementGetDevice(element)
            MainActor.assumeIsolated {
                detectActiveKeyboard(device: device)
            }
        }
    }

    private func detectActiveKeyboard(device: IOHIDDevice) {
        guard let keyboardName = getKeyboardName(from: device) else {
            return
        }
        if keyboardName == lastKeyboard.name {
            return
        }

        logger.debug("Keyboard detected: \(keyboardName)")

        for keyboard in managedKeyboards {
            if keyboard.name == keyboardName {
                logger.debug("Switching layout to \(keyboard.layoutInfo.layoutName) for keyboard \(keyboardName)")
                layoutDetector.switchToLayout(layoutId: keyboard.layoutInfo.layoutId)
                lastKeyboard = keyboard
                onKeyboardSwitch?(keyboard)
                break
            }
        }
    }
}
