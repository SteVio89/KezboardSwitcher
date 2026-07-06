//
//  LayoutDetector.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 30.07.25.
//

import Foundation
import Carbon
import os.log

struct LayoutDetector {
    private let logger = Logger(subsystem: "de.stevio.KezboardSwitcher", category: "LayoutDetector")

    func getAllLayouts() -> [LayoutInfo] {
        var layouts: [LayoutInfo] = []

        enumerateInputSources(includeAllInstalled: true, layoutsOnly: true) { inputSource in
            guard let idRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID),
                  let nameRef = TISGetInputSourceProperty(inputSource, kTISPropertyLocalizedName) else {
                return true
            }
            let layoutId = Unmanaged<CFString>.fromOpaque(idRef).takeUnretainedValue() as String
            let layoutName = Unmanaged<CFString>.fromOpaque(nameRef).takeUnretainedValue() as String

            let isEnabled = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsEnabled)
                .map { Unmanaged<CFBoolean>.fromOpaque($0).takeUnretainedValue() == kCFBooleanTrue }
                ?? false

            layouts.append(LayoutInfo(layoutId: layoutId, layoutName: layoutName, isEnabled: isEnabled))
            return true
        }

        return layouts.sorted { $0.layoutName.localizedCaseInsensitiveCompare($1.layoutName) == .orderedAscending }
    }

    func enableLayout(layoutId: String) {
        var found = false
        enumerateInputSources(includeAllInstalled: true, layoutsOnly: true) { inputSource in
            guard let idRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) else {
                return true
            }
            let currentId = Unmanaged<CFString>.fromOpaque(idRef).takeUnretainedValue() as String
            if currentId == layoutId {
                found = true
                let status = TISEnableInputSource(inputSource)
                if status == noErr {
                    logger.debug("Enabled layout \(layoutId)")
                } else {
                    logger.error("TISEnableInputSource failed with status \(status) for \(layoutId)")
                }
                return false
            }
            return true
        }
        if !found {
            logger.error("Layout \(layoutId) not found in installable input sources")
        }
    }

    func currentLayoutId() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let idRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(idRef).takeUnretainedValue() as String
    }

    /// Selects the enabled input source with the given ID as the active keyboard layout.
    /// - Parameter layoutId: The `kTISPropertyInputSourceID` of the layout to activate.
    /// - Returns: `true` if `TISSelectInputSource` succeeded; `false` if the layout is
    ///   not among the enabled input sources, is not selectable, or selection failed.
    func switchToLayout(layoutId: String) -> Bool {
        var found = false
        var switched = false
        enumerateInputSources { inputSource in
            guard let idRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) else {
                return true
            }
            let currentLayoutId = Unmanaged<CFString>.fromOpaque(idRef).takeUnretainedValue() as String
            if currentLayoutId == layoutId {
                found = true

                let isSelectable = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsSelectCapable)
                    .map { Unmanaged<CFBoolean>.fromOpaque($0).takeUnretainedValue() == kCFBooleanTrue }
                    ?? false

                if !isSelectable {
                    logger.error("Input source \(layoutId) is not selectable")
                    return false
                }

                let status = TISSelectInputSource(inputSource)
                if status == noErr {
                    logger.debug("Switched to layout \(layoutId)")
                    switched = true
                } else {
                    logger.error("TISSelectInputSource failed with status \(status) for \(layoutId)")
                }
                return false
            }
            return true
        }
        if !found {
            logger.error("Layout \(layoutId) not found in enabled input sources")
        }
        return switched
    }

    /// Iterates over keyboard input sources. Return `true` to continue, `false` to stop.
    /// - Parameters:
    ///   - includeAllInstalled: When `true`, includes sources that aren't enabled yet.
    ///   - layoutsOnly: When `true`, restricts to `kTISTypeKeyboardLayout` (excludes input methods).
    private func enumerateInputSources(includeAllInstalled: Bool = false, layoutsOnly: Bool = false, _ body: (TISInputSource) -> Bool) {
        var properties: [CFString: Any] = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as Any
        ]

        if layoutsOnly {
            properties[kTISPropertyInputSourceType] = kTISTypeKeyboardLayout as Any
        }

        if !includeAllInstalled {
            properties[kTISPropertyInputSourceIsEnabled] = kCFBooleanTrue as Any
        }

        guard let sourcesUnmanaged = TISCreateInputSourceList(properties as CFDictionary, includeAllInstalled) else {
            logger.error("Failed to get input source list")
            return
        }

        let sourcesList = sourcesUnmanaged.takeRetainedValue()
        let count = CFArrayGetCount(sourcesList)

        for i in 0..<count {
            guard let source = CFArrayGetValueAtIndex(sourcesList, i) else { continue }
            let inputSource = Unmanaged<TISInputSource>.fromOpaque(source).takeUnretainedValue()
            if !body(inputSource) { break }
        }
    }
}
