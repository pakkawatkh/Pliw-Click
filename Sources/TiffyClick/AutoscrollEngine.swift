import AppKit
import CoreGraphics
import Foundation
import TiffyClickCore

/// Tag placed on synthetic CGEvents posted by tiffy-click so our own event tap ignores them.
let kTiffySyntheticEventTag: Int64 = 0x54494646 // "TIFF"

/// Manages Windows-style universal Autoscroll (both Hold-and-Move and Smart Click-to-Toggle).
final class AutoscrollEngine {
    enum State {
        case inactive
        /// Middle button is down, waiting to see if user drags past threshold (Hold) or releases quickly (Toggle).
        case pending(anchor: CGPoint)
        /// Actively scrolling while holding middle button; releasing stops autoscroll.
        case activeHold(anchor: CGPoint)
        /// Actively scrolling in locked toggle mode; next click or Esc stops autoscroll.
        case activeToggle(anchor: CGPoint)
    }

    private let lock = NSLock()
    private var state: State = .inactive
    private var currentCursor: CGPoint = .zero
    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.local.tiffy-click.autoscroll", qos: .userInteractive)
    private let overlay: AutoscrollOverlayController

    init(overlay: AutoscrollOverlayController) {
        self.overlay = overlay
    }

    var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        switch state {
        case .activeHold, .activeToggle:
            return true
        case .inactive, .pending:
            return false
        }
    }

    /// Handles a middle mouse down event. Returns `true` if the event should be swallowed.
    func handleMiddleDown(at location: CGPoint, bundleID: String?, config: ConfigSnapshot) -> Bool {
        guard config.autoscrollEnabled else { return false }

        lock.lock()
        switch state {
        case .activeToggle, .activeHold:
            // Clicking while autoscroll is active stops it cleanly
            state = .inactive
            lock.unlock()
            stopScrolling()
            return true

        case .inactive, .pending:
            currentCursor = location
            lock.unlock()

            // Autoscroll is strictly for scrollable empty webpage areas inside browsers
            guard SystemPermissions.canActivateAutoscroll(
                at: location,
                bundleID: bundleID,
                browsersOnly: true
            ) else {
                return false
            }

            lock.lock()
            state = .pending(anchor: location)
            lock.unlock()
            startScrolling(at: location, horizontalEnabled: config.autoscrollHorizontalEnabled)
            return true
        }
    }

    /// Handles mouse movement / dragging.
    func handleCursorMove(to location: CGPoint, config: ConfigSnapshot) {
        lock.lock()
        currentCursor = location

        if case let .pending(anchor) = state {
            let dist = AutoscrollMath.distance(from: anchor, to: location)
            if dist >= config.autoscrollDragThreshold {
                state = .activeHold(anchor: anchor)
            }
        }
        lock.unlock()
    }

    /// Handles middle mouse up event. Returns `true` if the event should be swallowed.
    func handleMiddleUp(at location: CGPoint, config: ConfigSnapshot) -> Bool {
        lock.lock()
        let currentState = state

        switch currentState {
        case .inactive:
            lock.unlock()
            return false

        case .activeHold:
            // User held and dragged -> stop autoscroll on release
            state = .inactive
            lock.unlock()
            stopScrolling()
            return true

        case .activeToggle:
            lock.unlock()
            return true

        case let .pending(anchor):
            // Released without dragging far -> lock into Toggle Autoscroll (Windows style!)
            state = .activeToggle(anchor: anchor)
            lock.unlock()
            return true
        }
    }

    /// Cancels toggle autoscroll when user clicks left/right button or presses Esc.
    /// Returns `true` if the click/key should be swallowed.
    func handleCancelTrigger() -> Bool {
        lock.lock()
        let wasToggle: Bool
        if case .activeToggle = state {
            state = .inactive
            wasToggle = true
        } else {
            wasToggle = false
        }
        lock.unlock()

        if wasToggle {
            stopScrolling()
            return true
        }
        return false
    }

    func forceStop() {
        lock.lock()
        let shouldStop: Bool
        if case .inactive = state {
            shouldStop = false
        } else {
            state = .inactive
            shouldStop = true
        }
        lock.unlock()

        if shouldStop {
            stopScrolling()
        }
    }

    private func startScrolling(at anchor: CGPoint, horizontalEnabled: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.overlay.show(at: anchor, horizontalEnabled: horizontalEnabled)
        }

        timer?.cancel()
        let newTimer = DispatchSource.makeTimerSource(queue: timerQueue)
        // 60Hz smooth pixel scrolling
        newTimer.schedule(deadline: .now(), repeating: .milliseconds(16))
        newTimer.setEventHandler { [weak self] in
            self?.tick()
        }
        timer = newTimer
        newTimer.resume()
    }

    private func stopScrolling() {
        timer?.cancel()
        timer = nil
        DispatchQueue.main.async { [weak self] in
            self?.overlay.hide()
        }
    }

    private func tick() {
        let config = TiffyClickConfig.shared.snapshot
        lock.lock()
        let anchor: CGPoint?
        switch state {
        case let .activeHold(a), let .activeToggle(a), let .pending(a):
            anchor = a
        default:
            anchor = nil
        }
        let cursor = currentCursor
        lock.unlock()

        guard let anchor else { return }

        let step = AutoscrollMath.computeStep(
            anchor: anchor,
            current: cursor,
            deadzone: config.autoscrollDeadzone,
            speedMultiplier: config.autoscrollSpeed,
            horizontalEnabled: config.autoscrollHorizontalEnabled,
            invertDirection: config.autoscrollInvertDirection
        )

        DispatchQueue.main.async { [weak self] in
            self?.overlay.update(angle: step.angleRadians)
        }

        if step.wheelY != 0 || step.wheelX != 0 {
            if let scrollEvent = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 2,
                wheel1: step.wheelY,
                wheel2: step.wheelX,
                wheel3: 0
            ) {
                scrollEvent.setIntegerValueField(.eventSourceUserData, value: kTiffySyntheticEventTag)
                scrollEvent.post(tap: .cghidEventTap)
            }
        }
    }

    static func postSyntheticMiddleClick(at location: CGPoint) {
        if let down = CGEvent(
            mouseEventSource: nil,
            mouseType: .otherMouseDown,
            mouseCursorPosition: location,
            mouseButton: .center
        ) {
            down.setIntegerValueField(.eventSourceUserData, value: kTiffySyntheticEventTag)
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(
            mouseEventSource: nil,
            mouseType: .otherMouseUp,
            mouseCursorPosition: location,
            mouseButton: .center
        ) {
            up.setIntegerValueField(.eventSourceUserData, value: kTiffySyntheticEventTag)
            up.post(tap: .cghidEventTap)
        }
    }
}
