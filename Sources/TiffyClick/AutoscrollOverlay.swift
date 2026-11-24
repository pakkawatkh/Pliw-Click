import AppKit
import SwiftUI
import TiffyClickCore

@MainActor
final class AutoscrollOverlayModel: ObservableObject {
    @Published var direction: AutoscrollDirection = .none
    @Published var horizontalEnabled: Bool = true
    @Published var isVisible: Bool = false
}

/// True macOS Liquid Glass circular backdrop using NSVisualEffectView + crisp anti-aliased maskImage.
private struct LiquidGlassBackdrop: NSViewRepresentable {
    let diameter: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: diameter, height: diameter))
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
        view.maskImage = Self.circleMask(diameter: diameter)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.state = .active
    }

    private static func circleMask(diameter: CGFloat) -> NSImage {
        let img = NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        img.capInsets = NSEdgeInsets()
        img.resizingMode = .stretch
        return img
    }
}

private struct AutoscrollBadgeView: View {
    @ObservedObject var model: AutoscrollOverlayModel
    @Environment(\.colorScheme) private var colorScheme

    private let orbSize: CGFloat = 42

    private var isScrolling: Bool {
        model.direction != .none
    }

    private var dotOffset: CGSize {
        let shift: CGFloat = 2.2
        let dx: CGFloat = (model.direction.right ? shift : 0) - (model.direction.left ? shift : 0)
        let dy: CGFloat = (model.direction.down ? shift : 0) - (model.direction.up ? shift : 0)
        return CGSize(width: dx, height: dy)
    }

    private var inactiveChevronColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.62) : Color.black.opacity(0.55)
    }

    private var activeGlowColor: Color {
        Color.accentColor
    }

    var body: some View {
        ZStack {
            // 1. Floating shadow base (behind glass so blur stays crystal-clear)
            Circle()
                .fill(Color.black.opacity(0.01))
                .frame(width: orbSize, height: orbSize)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.50 : 0.22), radius: 11, x: 0, y: 5)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.30 : 0.12), radius: 2.5, x: 0, y: 1)

            // 2. Real behind-window macOS frosted glass blur
            LiquidGlassBackdrop(diameter: orbSize)
                .frame(width: orbSize, height: orbSize)

            // 3. Translucent Liquid Glass optical tint
            Circle()
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color.white.opacity(0.14), Color.white.opacity(0.03), Color.black.opacity(0.10)]
                            : [Color.white.opacity(0.46), Color.white.opacity(0.16), Color.white.opacity(0.24)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: orbSize, height: orbSize)

            // 4. Curved Liquid Glass specular dome reflection (top crescent sheen)
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.34 : 0.72),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: orbSize * 0.68, height: orbSize * 0.36)
                .offset(y: -orbSize * 0.24)
                .allowsHitTesting(false)

            // 5. Prismatic Liquid Glass rim (bright specular top-left & bottom-right catchlights)
            Circle()
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(colorScheme == .dark ? 0.68 : 0.95), location: 0.0),
                            .init(color: Color.white.opacity(colorScheme == .dark ? 0.14 : 0.32), location: 0.25),
                            .init(color: Color.white.opacity(colorScheme == .dark ? 0.45 : 0.80), location: 0.50),
                            .init(color: Color.white.opacity(colorScheme == .dark ? 0.14 : 0.32), location: 0.75),
                            .init(color: Color.white.opacity(colorScheme == .dark ? 0.68 : 0.95), location: 1.0)
                        ]),
                        center: .center,
                        angle: .degrees(-45)
                    ),
                    lineWidth: 1.15
                )
                .frame(width: orbSize, height: orbSize)

            // 6. Ultra-fine outer hairline separator for crisp contrast on pure white or pure black pages
            Circle()
                .stroke(Color.black.opacity(colorScheme == .dark ? 0.45 : 0.14), lineWidth: 0.5)
                .frame(width: orbSize + 0.5, height: orbSize + 0.5)

            // 7. Subtle inner precision ring
            Circle()
                .stroke(
                    (isScrolling ? activeGlowColor : (colorScheme == .dark ? Color.white : Color.black))
                        .opacity(isScrolling ? 0.35 : 0.12),
                    lineWidth: 0.75
                )
                .frame(width: 14, height: 14)

            // 8. Center jewel dot (glides subtly in active scroll direction)
            Circle()
                .fill(
                    isScrolling
                        ? activeGlowColor
                        : (colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.76))
                )
                .frame(width: 5.2, height: 5.2)
                .shadow(color: isScrolling ? activeGlowColor.opacity(0.65) : .clear, radius: 4)
                .offset(dotOffset)

            // 9. Directional chevrons with subtle active glow & glide
            directionChevron(
                symbol: "chevron.up",
                active: model.direction.up,
                offset: CGSize(width: 0, height: model.direction.up ? -14.2 : -12.8)
            )

            directionChevron(
                symbol: "chevron.down",
                active: model.direction.down,
                offset: CGSize(width: 0, height: model.direction.down ? 14.2 : 12.8)
            )

            if model.horizontalEnabled {
                directionChevron(
                    symbol: "chevron.left",
                    active: model.direction.left,
                    offset: CGSize(width: model.direction.left ? -14.2 : -12.8, height: 0)
                )

                directionChevron(
                    symbol: "chevron.right",
                    active: model.direction.right,
                    offset: CGSize(width: model.direction.right ? 14.2 : 12.8, height: 0)
                )
            }
        }
        .frame(width: 72, height: 72)
        .scaleEffect(model.isVisible ? 1.0 : 0.76)
        .opacity(model.isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.20, dampingFraction: 0.74), value: model.isVisible)
        .animation(.easeOut(duration: 0.10), value: model.direction)
    }

    @ViewBuilder
    private func directionChevron(symbol: String, active: Bool, offset: CGSize) -> some View {
        Image(systemName: symbol)
            .font(.system(size: active ? 8.2 : 7.2, weight: active ? .bold : .semibold))
            .foregroundColor(active ? activeGlowColor : inactiveChevronColor)
            .shadow(color: active ? activeGlowColor.opacity(0.55) : .clear, radius: 3.5)
            .offset(offset)
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
        let size: CGFloat = 72
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
            contentRect: NSRect(x: 0, y: 0, width: 72, height: 72),
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
        hosting.frame = NSRect(x: 0, y: 0, width: 72, height: 72)
        p.contentView = hosting

        self.panel = p
        return p
    }
}
