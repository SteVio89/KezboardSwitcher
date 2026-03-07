//
//  Keyboard.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 29.07.25.
//

import Foundation

enum KeyboardStatus: Int, CaseIterable, Codable, Hashable, Equatable {
    case new = 0
    case configured = 1
    case ignored = 2

    var displayName: String {
        switch self {
        case .new:
            return "New"
        case .configured:
            return "Configured"
        case .ignored:
            return "Ignored"
        }
    }
}

struct LayoutInfo: Codable, Hashable, Equatable {
    var layoutId: String
    var layoutName: String

    init(layoutId: String = "", layoutName: String = "") {
        self.layoutId = layoutId
        self.layoutName = layoutName
    }

    enum CodingKeys: String, CodingKey {
        case layoutId
        case layoutName
    }
}

struct Keyboard: Codable, Hashable, Equatable, Identifiable {
    var name: String
    var status: KeyboardStatus
    var layoutInfo: LayoutInfo

    var id: String { name }

    init(name: String, status: KeyboardStatus, layoutInfo: LayoutInfo = LayoutInfo()) {
        self.name = name
        self.status = status
        self.layoutInfo = layoutInfo
    }

    enum CodingKeys: String, CodingKey {
        case name
        case status
        case layoutInfo
    }
}

extension Keyboard: CustomStringConvertible {
    var description: String {
        return "Keyboard(name: \"\(name)\", status: \(status.displayName), layoutInfo: \(layoutInfo))"
    }
}

extension LayoutInfo: CustomStringConvertible {
    var description: String {
        return "LayoutInfo(id: \"\(layoutId)\", name: \"\(layoutName)\")"
    }
}
