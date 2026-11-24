import AppKit
import SwiftUI
import TiffyClickCore

@MainActor
final class AutoscrollOverlayModel: ObservableObject {
    @Published var direction: AutoscrollDirection = .none
    @Published var horizontalEnabled: Bool = true
    @Published var isVisible: Bool = false
}

/// Native macOS NSVisualEffectView wrapper for true behind-window frosted glass (Sonoma / Sequoia style).
private struct MacGlassCircle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 18
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.state = .active
    }
}

private struct AutoscrollBadgeView: View {
    @ObservedObject var model: AutoscrollOverlayModel
    @Environment(\.colorScheme) private var colorScheme

    private var dotOffset: CGSize {
        let shift: CGFloat = 1.6
        let dx: CGFloat = (model.direction.right ? shift : 0) - (model.direction.left ? shift : 0)
        let dy: CGFloat = (model.direction.down ? shift : 0) - (model.direction.up ? shift : 0)
        return CGSize(width: dx, height: dy)
    }

    private var inactiveChevronColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.45) : Color.black.opacity(0.42)
    }

    private var activeChevronColor: Color {
        Color.accentColor
    }

    private var centerDotColor: Color {
        let anyActive = model.direction != .none
        if anyActive {
            return Color.accentColor
        }
        return colorScheme == .dark ? Color.white.opacity(0.88) : Color.black.opacity(0.75)
    }

    var body: some View {
        ZStack {
            // Native frosted macOS HUD glass orb
            MacGlassCircle()
                .frame(width: 36, height: 36)
                // Subtle glass tint for contrast on both bright white & dark web pages
                .overlay(
                    Circle()
                        .fill(
                            colorScheme == .dark
                                ? Color.black.opacity(0.18)
                                : Color.white.opacity(0.28)
                        )
                )
                // Specular top-to-bottom Apple glass rim
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.42 : 0.85),
                                    Color.white.opacity(colorScheme == .dark ? 0.10 : 0.25)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.9
                        )
                )
                // Crisp hairline outer separator
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(colorScheme == .dark ? 0.35 : 0.14), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.42 : 0.20), radius: 7, x: 0, y: 3)

            // Center precision dot (shifts gently toward scroll direction)
            Circle()
                .fill(centerDotColor)
                .frame(width: 4.5, height: 4.5)
                .offset(dotOffset)

            // Up chevron
            Image(systemName: "chevron.up")
                .font(.system(size: 7.2, weight: model.direction.up ? .bold : .semibold))
                .foregroundColor(model.direction.up ? activeChevronColor : inactiveChevronColor)
                .offset(y: model.direction.up ? -12.0 : -10.8)

            // Down chevron
            Image(systemName: "chevron.down")
                .font(.system(size: 7.2, weight: model.direction.down ? .bold : .semibold))
                .foregroundColor(model.direction.down ? activeChevronColor : inactiveChevronColor)
                .offset(y: model.direction.down ? 12.0 : 10.8)

            if model.horizontalEnabled {
                // Left chevron
                Image(systemName: "chevron.left")
                    .font(.system(size: 7.2, weight: model.direction.left ? .bold : .semibold))
                    .foregroundColor(model.direction.left ? activeChevronColor : inactiveChevronColor)
                    .offset(x: model.direction.left ? -12.0 : -10.8)

                // Right chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 7.2, weight: model.direction.right ? .bold : .semibold))
                    .foregroundColor(model.direction.right ? activeChevronColor : inactiveChevronColor)
                    .offset(x: model.direction.right ? 12.0 : 10.8)
            }
        }
        .frame(width: 56, height: 56)
        .scaleEffect(model.isVisible ? 1.0 : 0.80)
        .opacity(model.isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.18, dampingFraction: 0.78), value: model.isVisible)
        .animation(.easeOut(duration: 0.10), value: model.direction)
    }
}

@MainActor
final class AutoscrollOverlayController {
    private let model = AutoscrollOverlayModel()
    private var panel: NSPanel?

    func show(at cgPoint: CGPoint, horizontalEnabled: Bool) {
        model.direction = .none
        model.horizontalEnabled = horizontalEnabled
        model.isVisible = false

        let panel = ensurePanel()
        let size: CGFloat = 56
        // Convert CG global coordinates (origin top-left of primary screen) to Cocoa (origin bottom-left of primary screen)
        let primaryHeight = NSScreen.screens.first?.frame.height ?? NSScreen.main?.frame.height ?? 1080
        let cocoaX = cgPoint.x - size / 2
        let cocoaY = (primaryHeight - cgPoint.y) - size / 2

        panel.setFrame(NSRect(x: cocoaX, y: cocoaY, width: size, height: size), display: true)
        panel.orderFrontRegardless()

        DispatchQueue.main.async { [weak self] in
            self?.model.isVisible = true
        }
    }

    func update(direction: AutoscrollDirection) {
        if model.direction != direction {
            model.direction = direction
        }
    }

    func hide() {
        model.isVisible = false
        model.direction = .none
        panel?.orderOut(nil)
    }

    private func ensurePanel() -> NSPanel {
        if let existing = panel { return existing }

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 56, height: 56),
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
        hosting.frame = NSRect(x: 0, y: 0, width: 56, height: 56)
        p.contentView = hosting

        self.panel = p
        return p
    }
}
