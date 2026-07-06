//
//  Keyboard.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 29.07.25.
//

import Foundation

enum KeyboardStatus: String, Codable, Hashable {
    case new
    case configured
    case ignored

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

struct LayoutInfo: Codable, Hashable {
    var layoutId: String
    var layoutName: String
    var isEnabled: Bool

    init(layoutId: String = "", layoutName: String = "", isEnabled: Bool = true) {
        self.layoutId = layoutId
        self.layoutName = layoutName
        self.isEnabled = isEnabled
    }

    enum CodingKeys: String, CodingKey {
        case layoutId, layoutName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        layoutId = try container.decode(String.self, forKey: .layoutId)
        layoutName = try container.decode(String.self, forKey: .layoutName)
        isEnabled = true
    }
}

struct Keyboard: Codable, Hashable, Identifiable {
    var name: String
    var status: KeyboardStatus
    var layoutInfo: LayoutInfo

    var id: String { name }

    init(name: String, status: KeyboardStatus, layoutInfo: LayoutInfo = LayoutInfo()) {
        self.name = name
        self.status = status
        self.layoutInfo = layoutInfo
    }
}

