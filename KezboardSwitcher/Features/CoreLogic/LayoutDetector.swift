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

    func getAvailableLayouts() -> [LayoutInfo] {
        var layouts: [LayoutInfo] = []

        enumerateInputSources { inputSource in
            guard let idRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID),
                  let nameRef = TISGetInputSourceProperty(inputSource, kTISPropertyLocalizedName) else {
                return true
            }
            let layoutId = Unmanaged<CFString>.fromOpaque(idRef).takeUnretainedValue() as String
            let layoutName = Unmanaged<CFString>.fromOpaque(nameRef).takeUnretainedValue() as String
            layouts.append(LayoutInfo(layoutId: layoutId, layoutName: layoutName))
            return true
        }

        return layouts.sorted { $0.layoutName.localizedCaseInsensitiveCompare($1.layoutName) == .orderedAscending }
    }

    func switchToLayout(layoutId: String) {
        enumerateInputSources { inputSource in
            guard let idRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) else {
                return true
            }
            let currentLayoutId = Unmanaged<CFString>.fromOpaque(idRef).takeUnretainedValue() as String
            if currentLayoutId == layoutId {
                TISSelectInputSource(inputSource)
                logger.debug("Successfully switched to layout \(layoutId)")
                return false
            }
            return true
        }
    }

    /// Iterates over enabled keyboard input sources. Return `true` to continue, `false` to stop.
    private func enumerateInputSources(_ body: (TISInputSource) -> Bool) {
        let properties: [CFString: Any] = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as Any,
            kTISPropertyInputSourceIsEnabled: kCFBooleanTrue as Any
        ]

        guard let sourcesUnmanaged = TISCreateInputSourceList(properties as CFDictionary, false) else {
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
