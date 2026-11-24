import Foundation

public struct NormalizedTouchPoint: Equatable, Sendable {
    public let x: Float
    public let y: Float

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
}

public struct TouchFrameResult: Equatable, Sendable {
    public let isTargetFingerCountActive: Bool
    public let shouldTriggerTapMiddleClick: Bool

    public init(isTargetFingerCountActive: Bool, shouldTriggerTapMiddleClick: Bool) {
        self.isTargetFingerCountActive = isTargetFingerCountActive
        self.shouldTriggerTapMiddleClick = shouldTriggerTapMiddleClick
    }
}

/// Pure, thread-safe state machine for multitouch finger counting, palm rejection, and tap-to-middle-click.
public final class TapGestureRecognizer {
    private var maybeTap = false
    private var touchStartTime: TimeInterval?
    private var lastEmulatedTapTime: TimeInterval?
    private var lastNaturalMiddleClickTime: TimeInterval?
    private var startPosSum: SIMD2<Float> = .zero
    private var endPosSum: SIMD2<Float> = .zero
    private var sampledFingerCount: Int = 0

    public init() {}

    public func recordNaturalMiddleClick(at timestamp: TimeInterval) {
        lastNaturalMiddleClickTime = timestamp
    }

    public func reset() {
        maybeTap = false
        touchStartTime = nil
        startPosSum = .zero
        endPosSum = .zero
        sampledFingerCount = 0
    }

    /// Processes a multitouch frame with normalized coordinates (0...1).
    public func processFrame(
        touches: [NormalizedTouchPoint],
        timestamp: TimeInterval,
        config: ConfigSnapshot
    ) -> TouchFrameResult {
        guard config.isEnabled else {
            reset()
            return TouchFrameResult(isTargetFingerCountActive: false, shouldTriggerTapMiddleClick: false)
        }

        // Palm rejection: ignore edge touches if configured
        let margin = max(0, min(0.25, config.palmRejectionMargin))
        let validTouches: [NormalizedTouchPoint]
        if margin > 0 {
            validTouches = touches.filter { $0.x >= margin && $0.x <= (1.0 - margin) }
        } else {
            validTouches = touches
        }

        let nFingers = validTouches.count
        let targetFingers = config.minimumFingers
        let isTargetActive = config.allowMoreFingers ? (nFingers >= targetFingers) : (nFingers == targetFingers)

        guard config.tapToClick else {
            return TouchFrameResult(isTargetFingerCountActive: isTargetActive, shouldTriggerTapMiddleClick: false)
        }

        if nFingers == 0 {
            let triggered = handleTouchEnd(timestamp: timestamp, config: config)
            return TouchFrameResult(isTargetFingerCountActive: false, shouldTriggerTapMiddleClick: triggered)
        }

        if touchStartTime == nil {
            touchStartTime = timestamp
            maybeTap = true
            startPosSum = .zero
            endPosSum = .zero
            sampledFingerCount = 0
        } else if maybeTap, let start = touchStartTime {
            if (timestamp - start) > config.maxTapDurationSec {
                maybeTap = false
            }
        }

        if nFingers < targetFingers {
            return TouchFrameResult(isTargetFingerCountActive: false, shouldTriggerTapMiddleClick: false)
        }

        if !config.allowMoreFingers && nFingers > targetFingers {
            maybeTap = false
            startPosSum = .zero
            sampledFingerCount = 0
            return TouchFrameResult(isTargetFingerCountActive: false, shouldTriggerTapMiddleClick: false)
        }

        // Accumulate centroid of the active fingers
        var sum: SIMD2<Float> = .zero
        for t in validTouches {
            sum += SIMD2<Float>(t.x, t.y)
        }
        let centroid = sum / Float(nFingers)

        if maybeTap {
            startPosSum = centroid
            endPosSum = centroid
            sampledFingerCount = nFingers
            maybeTap = false
        } else if sampledFingerCount > 0 {
            endPosSum = centroid
        }

        return TouchFrameResult(isTargetFingerCountActive: isTargetActive, shouldTriggerTapMiddleClick: false)
    }

    private func handleTouchEnd(timestamp: TimeInterval, config: ConfigSnapshot) -> Bool {
        guard let start = touchStartTime else { return false }
        let elapsed = timestamp - start
        let hadSample = sampledFingerCount > 0
        let pos1 = startPosSum
        let pos2 = endPosSum

        touchStartTime = nil
        maybeTap = false
        startPosSum = .zero
        endPosSum = .zero
        sampledFingerCount = 0

        guard hadSample, elapsed <= config.maxTapDurationSec else { return false }

        // Manhattan distance of centroid movement (normalized 0...1)
        let delta = abs(pos1.x - pos2.x) + abs(pos1.y - pos2.y)
        guard delta < config.maxTapDistance else { return false }

        // Prevent double-firing right after a physical 3-finger click
        if let natural = lastNaturalMiddleClickTime,
           (timestamp - natural) <= config.maxTapDurationSec * 0.75 {
            return false
        }

        // Debounce rapid duplicate tap events
        if let lastTap = lastEmulatedTapTime,
           (timestamp - lastTap) < config.maxTapDurationSec * 0.3 {
            return false
        }

        lastEmulatedTapTime = timestamp
        return true
    }
}
