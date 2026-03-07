//
//  Theme.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 07.03.26.
//

import SwiftUI

enum Theme {
    // MARK: - Brand Colors (from app icon gradient)
    static let accentBlue = Color(nsColor: .controlAccentColor)
    static let skyBlue = Color(red: 0.353, green: 0.784, blue: 0.980) // #5AC8FA

    // MARK: - Status Colors
    static let statusConfigured = Color.green
    static let statusNew = Color.orange
    static let statusIgnored = Color.secondary

    static func statusColor(for status: KeyboardStatus) -> Color {
        switch status {
        case .new: statusNew
        case .configured: statusConfigured
        case .ignored: statusIgnored
        }
    }

    // MARK: - Card Style
    static let cardRadius: CGFloat = 10
    static let cardPadding: CGFloat = 10
}

struct CardStyle: ViewModifier {
    var isSelected: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(Theme.cardPadding)
            .background {
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            }
    }
}

extension View {
    func cardStyle(isSelected: Bool = false) -> some View {
        modifier(CardStyle(isSelected: isSelected))
    }
}
