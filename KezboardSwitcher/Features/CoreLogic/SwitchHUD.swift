//
//  SwitchHUD.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 08.03.26.
//

import AppKit
import SwiftUI

@MainActor
final class SwitchHUD {
    static let shared = SwitchHUD()

    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    private init() {}

    func show(keyboardName: String, layoutName: String) {
        hideTask?.cancel()

        let hostingView = NSHostingView(rootView: SwitchHUDContent(
            layoutName: layoutName,
            keyboardName: keyboardName
        ))
        hostingView.setFrameSize(hostingView.fittingSize)

        let panel = self.panel ?? createPanel()
        self.panel = panel

        panel.contentView = hostingView
        panel.setContentSize(hostingView.fittingSize)
        positionPanel(panel)

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }

        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        }
    }

    private func createPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        return panel
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.maxY - panelSize.height - 40
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private struct SwitchHUDContent: View {
    let layoutName: String
    let keyboardName: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "keyboard")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)

            Text(layoutName)
                .font(.system(size: 18, weight: .semibold))

            Text(keyboardName)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(minWidth: 200)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        }
    }
}
