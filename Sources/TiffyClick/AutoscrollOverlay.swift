import AppKit
import SwiftUI
import TiffyClickCore

@MainActor
final class AutoscrollOverlayModel: ObservableObject {
    /// Continuous angle in radians (`atan2(dy, dx)`) pointing toward cursor, or `nil` when idle in deadzone.
    @Published var activeAngle: Double? = nil
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

    private let orbSize: CGFloat = 28

    private var isScrolling: Bool {
        model.activeAngle != nil
    }

    private var dotOffset: CGSize {
        guard let angle = model.activeAngle else { return .zero }
        let shift: CGFloat = 1.6
        return CGSize(width: CGFloat(cos(angle)) * shift, height: CGFloat(sin(angle)) * shift)
    }

    private var arrowOffset: CGSize {
        guard let angle = model.activeAngle else { return .zero }
        let radius: CGFloat = 8.8
        return CGSize(width: CGFloat(cos(angle)) * radius, height: CGFloat(sin(angle)) * radius)
    }

    private var activeGlowColor: Color {
        Color.accentColor
    }

    var body: some View {
        ZStack {
            // 1. Floating shadow base
            Circle()
                .fill(Color.black.opacity(0.01))
                .frame(width: orbSize, height: orbSize)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.48 : 0.22), radius: 8, x: 0, y: 3.5)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12), radius: 2, x: 0, y: 1)

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

            // 4. Curved Liquid Glass specular dome reflection
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

            // 5. Prismatic Liquid Glass rim
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
                    lineWidth: 1.0
                )
                .frame(width: orbSize, height: orbSize)

            // 6. Hairline outer separator for crisp contrast on white or dark pages
            Circle()
                .stroke(Color.black.opacity(colorScheme == .dark ? 0.45 : 0.14), lineWidth: 0.5)
                .frame(width: orbSize + 0.5, height: orbSize + 0.5)

            // 7. Minimal center dot
            Circle()
                .fill(
                    isScrolling
                        ? activeGlowColor
                        : (colorScheme == .dark ? Color.white.opacity(0.88) : Color.black.opacity(0.72))
                )
                .frame(width: 4.2, height: 4.2)
                .shadow(color: isScrolling ? activeGlowColor.opacity(0.6) : .clear, radius: 3)
                .offset(dotOffset)

            // 8. Single 360° orbiting chevron pointing directly toward the cursor
            if let angle = model.activeAngle {
                Image(systemName: "chevron.up")
                    .font(.system(size: 6.8, weight: .bold))
                    .foregroundColor(activeGlowColor)
                    .shadow(color: activeGlowColor.opacity(0.55), radius: 2.5)
                    .rotationEffect(.radians(angle + .pi / 2))
                    .offset(arrowOffset)
                    .transition(.opacity.combined(with: .scale(scale: 0.6)))
            }
        }
        .frame(width: 54, height: 54)
        .scaleEffect(model.isVisible ? 1.0 : 0.75)
        .opacity(model.isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.18, dampingFraction: 0.76), value: model.isVisible)
        .animation(.easeOut(duration: 0.10), value: isScrolling)
    }
}

@MainActor
final class AutoscrollOverlayController {
    private let model = AutoscrollOverlayModel()
    private var panel: NSPanel?

    func show(at cgPoint: CGPoint, horizontalEnabled: Bool) {
        model.activeAngle = nil
        model.isVisible = false

        let panel = ensurePanel()
        let size: CGFloat = 54
        let primaryHeight = NSScreen.screens.first?.frame.height ?? NSScreen.main?.frame.height ?? 1080
        let cocoaX = cgPoint.x - size / 2
        let cocoaY = (primaryHeight - cgPoint.y) - size / 2

        panel.setFrame(NSRect(x: cocoaX, y: cocoaY, width: size, height: size), display: true)
        panel.orderFrontRegardless()

        DispatchQueue.main.async { [weak self] in
            self?.model.isVisible = true
        }
    }

    func update(angle: Double?) {
        model.activeAngle = angle
    }

    func hide() {
        model.isVisible = false
        model.activeAngle = nil
        panel?.orderOut(nil)
    }

    private func ensurePanel() -> NSPanel {
        if let existing = panel { return existing }

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 54, height: 54),
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
        hosting.frame = NSRect(x: 0, y: 0, width: 54, height: 54)
        p.contentView = hosting

        self.panel = p
        return p
    }
}
