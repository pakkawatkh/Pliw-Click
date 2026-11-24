import AppKit
import SwiftUI
import TiffyClickCore

@MainActor
final class AutoscrollOverlayModel: ObservableObject {
    @Published var direction: AutoscrollDirection = .none
    @Published var horizontalEnabled: Bool = true
}

private struct AutoscrollBadgeView: View {
    @ObservedObject var model: AutoscrollOverlayModel

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .fill(Color.black.opacity(0.45))
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.65), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 2)

            // Center dot
            Circle()
                .fill(Color.white)
                .frame(width: 4.5, height: 4.5)

            // Up chevron
            Image(systemName: "chevron.up")
                .font(.system(size: 7.5, weight: .bold))
                .foregroundColor(model.direction.up ? .cyan : .white.opacity(0.8))
                .offset(y: -10.5)

            // Down chevron
            Image(systemName: "chevron.down")
                .font(.system(size: 7.5, weight: .bold))
                .foregroundColor(model.direction.down ? .cyan : .white.opacity(0.8))
                .offset(y: 10.5)

            if model.horizontalEnabled {
                Image(systemName: "chevron.left")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(model.direction.left ? .cyan : .white.opacity(0.8))
                    .offset(x: -10.5)

                Image(systemName: "chevron.right")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(model.direction.right ? .cyan : .white.opacity(0.8))
                    .offset(x: 10.5)
            }
        }
        .frame(width: 34, height: 34)
    }
}

@MainActor
final class AutoscrollOverlayController {
    private let model = AutoscrollOverlayModel()
    private var panel: NSPanel?

    func show(at cgPoint: CGPoint, horizontalEnabled: Bool) {
        model.direction = .none
        model.horizontalEnabled = horizontalEnabled

        let panel = ensurePanel()
        let size: CGFloat = 40
        // Convert CG global coordinates (origin top-left of primary screen) to Cocoa (origin bottom-left of primary screen)
        let primaryHeight = NSScreen.screens.first?.frame.height ?? NSScreen.main?.frame.height ?? 1080
        let cocoaX = cgPoint.x - size / 2
        let cocoaY = (primaryHeight - cgPoint.y) - size / 2

        panel.setFrame(NSRect(x: cocoaX, y: cocoaY, width: size, height: size), display: true)
        panel.orderFrontRegardless()
    }

    func update(direction: AutoscrollDirection) {
        if model.direction != direction {
            model.direction = direction
        }
    }

    func hide() {
        panel?.orderOut(nil)
        model.direction = .none
    }

    private func ensurePanel() -> NSPanel {
        if let existing = panel { return existing }

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 40, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .screenSaver
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let hosting = NSHostingView(rootView: AutoscrollBadgeView(model: model))
        hosting.frame = NSRect(x: 0, y: 0, width: 40, height: 40)
        p.contentView = hosting

        self.panel = p
        return p
    }
}
