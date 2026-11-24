import Foundation
import CoreGraphics

public struct AutoscrollDirection: Equatable, Sendable {
    public let up: Bool
    public let down: Bool
    public let left: Bool
    public let right: Bool

    public static let none = AutoscrollDirection(up: false, down: false, left: false, right: false)

    public init(up: Bool, down: Bool, left: Bool, right: Bool) {
        self.up = up
        self.down = down
        self.left = left
        self.right = right
    }
}

public struct AutoscrollStep: Equatable, Sendable {
    /// Pixel delta for CGEvent scroll wheel1 (vertical: negative = scroll down page, positive = scroll up page).
    public let wheelY: Int32
    /// Pixel delta for CGEvent scroll wheel2 (horizontal: negative = scroll right, positive = scroll left).
    public let wheelX: Int32
    /// Active directional arrows to highlight in the HUD overlay.
    public let direction: AutoscrollDirection

    public static let zero = AutoscrollStep(wheelY: 0, wheelX: 0, direction: .none)
}

public enum AutoscrollMath {
    /// Computes distance between two screen points in CG coordinates (origin top-left).
    public static func distance(from a: CGPoint, to b: CGPoint) -> Double {
        let dx = Double(b.x - a.x)
        let dy = Double(b.y - a.y)
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Computes one 60Hz scroll tick based on anchor and current cursor in CG coordinates (y increases downward).
    public static func computeStep(
        anchor: CGPoint,
        current: CGPoint,
        deadzone: Double,
        speedMultiplier: Double,
        horizontalEnabled: Bool,
        invertDirection: Bool
    ) -> AutoscrollStep {
        let dx = Double(current.x - anchor.x)
        let dy = Double(current.y - anchor.y)

        let rawY = axisVelocity(delta: dy, deadzone: deadzone, speedMultiplier: speedMultiplier)
        let rawX = horizontalEnabled
            ? axisVelocity(delta: dx, deadzone: deadzone, speedMultiplier: speedMultiplier)
            : 0.0

        // In CGEvent pixel scroll:
        // Moving cursor DOWN (dy > 0) should scroll page DOWN -> negative wheelY on standard (non-inverted) macOS wheel.
        let sign: Double = invertDirection ? 1.0 : -1.0
        let wheelY = clampInt32(rawY * sign)
        let wheelX = clampInt32(rawX * sign)

        let direction = AutoscrollDirection(
            up: dy < -deadzone,
            down: dy > deadzone,
            left: horizontalEnabled && dx < -deadzone,
            right: horizontalEnabled && dx > deadzone
        )

        return AutoscrollStep(wheelY: wheelY, wheelX: wheelX, direction: direction)
    }

    /// Smooth nonlinear curve: gentle precision near deadzone, fast cruising further away.
    private static func axisVelocity(delta: Double, deadzone: Double, speedMultiplier: Double) -> Double {
        let magnitude = abs(delta)
        guard magnitude > deadzone else { return 0.0 }

        let effective = magnitude - deadzone
        // Base curve: linear component + gentle power curve for long-page cruising
        let pixelsPerTick = (effective * 0.14 + pow(effective / 22.0, 1.65) * 2.2) * max(0.1, speedMultiplier)
        let capped = min(pixelsPerTick, 140.0)
        return delta >= 0 ? capped : -capped
    }

    private static func clampInt32(_ value: Double) -> Int32 {
        let rounded = value.rounded()
        if rounded > Double(Int32.max) { return Int32.max }
        if rounded < Double(Int32.min) { return Int32.min }
        return Int32(rounded)
    }
}

public enum VersionComparator {
    /// Returns true if `latest` is strictly newer than `current` (e.g. "1.2.0" > "1.1.9").
    public static func isNewer(_ latest: String, than current: String) -> Bool {
        let lhs = parse(latest)
        let rhs = parse(current)
        let count = max(lhs.count, rhs.count)
        for i in 0..<count {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    private static func parse(_ version: String) -> [Int] {
        version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^v", with: "", options: .regularExpression)
            .split(separator: ".")
            .map { Int($0.prefix(while: { $0.isNumber })) ?? 0 }
    }
}
