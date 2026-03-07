//
//  LayoutDetector.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 30.07.25.
//

import Foundation
import Carbon

struct LayoutDetector {

    func getAvailableLayouts() -> [LayoutInfo] {
        let properties: [CFString: Any] = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as Any,
            kTISPropertyInputSourceIsEnabled: kCFBooleanTrue as Any
        ]

        guard let sourcesUnmanaged = TISCreateInputSourceList(properties as CFDictionary, false) else {
            return []
        }

        let sourcesList = sourcesUnmanaged.takeRetainedValue()
        let count = CFArrayGetCount(sourcesList)
        var layouts: [LayoutInfo] = []

        for i in 0..<count {
            guard let source = CFArrayGetValueAtIndex(sourcesList, i) else { continue }
            let inputSource = Unmanaged<TISInputSource>.fromOpaque(source).takeUnretainedValue()

            guard let idRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) else { continue }
            let layoutId = unsafeBitCast(idRef, to: CFString.self) as String

            guard let nameRef = TISGetInputSourceProperty(inputSource, kTISPropertyLocalizedName) else { continue }
            let layoutName = unsafeBitCast(nameRef, to: CFString.self) as String

            layouts.append(LayoutInfo(layoutId: layoutId, layoutName: layoutName))
        }

        return layouts.sorted { $0.layoutName.localizedCaseInsensitiveCompare($1.layoutName) == .orderedAscending }
    }
}
