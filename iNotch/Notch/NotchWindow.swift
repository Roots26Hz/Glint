import AppKit
import SwiftUI

/// Borderless, non-activating panel pinned over the hardware notch.
/// The panel is fixed at the maximum expanded size; all visual growth is
/// animated inside SwiftUI so the window never has to resize.
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class NotchWindowController {
    private var panel: NotchPanel?
    private let viewModel: NotchViewModel

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.placePanel()
            }
        }
        placePanel()
    }

    /// Prefer the built-in display with a real notch; otherwise fall back to
    /// the main screen with a pseudo-notch so the app still works everywhere.
    private static func targetScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    private static func notchSize(on screen: NSScreen) -> CGSize {
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            return CGSize(
                width: screen.frame.width - left.width - right.width,
                height: screen.safeAreaInsets.top
            )
        }
        // Non-notch display: draw a Dynamic Island-sized pseudo notch.
        return CGSize(width: 190, height: 32)
    }

    private func placePanel() {
        guard let screen = Self.targetScreen() else { return }

        let notch = Self.notchSize(on: screen)
        viewModel.notchSize = notch
        viewModel.refreshMode()

        let panelSize = NotchViewModel.maxPanelSize(for: notch)
        let frame = NSRect(
            x: screen.frame.midX - panelSize.width / 2,
            y: screen.frame.maxY - panelSize.height,
            width: panelSize.width,
            height: panelSize.height
        )

        if panel == nil {
            let panel = NotchPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.isMovable = false
            panel.hidesOnDeactivate = false
            panel.isFloatingPanel = true
            panel.becomesKeyOnlyIfNeeded = true
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.contentView = NSHostingView(rootView: NotchContainerView(viewModel: viewModel))
            self.panel = panel
        }

        panel?.setFrame(frame, display: true)
        panel?.orderFrontRegardless()
    }
}
