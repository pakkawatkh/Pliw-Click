import AppKit
import CoreGraphics
import Foundation
import MultitouchSupport
import TiffyClickCore

/// Central input coordinator combining MultitouchSupport (Trackpad / Magic Mouse)
/// with CGEventTap (Middle-Click, Middle-Drag, and Universal Autoscroll).
final class InputController {
    static let shared = InputController()

    private let stateLock = NSLock()
    private let tapRecognizer = TapGestureRecognizer()
    private var isTargetFingersDown = false
    private var convertedDragActive = false

    private var currentDevices: [MTDevice] = []
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var restartTimer: Timer?
    private var isUserSessionActive = true

    private var ioMonitor: IOMultitouchMonitor?
    private var autoscrollEngine: AutoscrollEngine!
    private var hasStarted = false

    private static let kCenterButton = Int64(CGMouseButton.center.rawValue)
    private static let kEscapeKeyCode: Int64 = 53

    private init() {}

    @MainActor
    func configure(overlay: AutoscrollOverlayController) {
        self.autoscrollEngine = AutoscrollEngine(overlay: overlay)
        self.ioMonitor = IOMultitouchMonitor { [weak self] in
            self?.scheduleRestart(delay: 2.0, reason: "Multitouch device connected")
        }
    }

    @MainActor
    func start(accessibilityMonitor: AccessibilityMonitor) {
        guard !hasStarted else { return }
        hasStarted = true

        logger.info("Starting tiffy-click input listeners")
        registerMultitouchDevices()
        ioMonitor?.start()
        observeSystemEvents()

        accessibilityMonitor.addListener { [weak self] trusted in
            guard let self else { return }
            if trusted {
                _ = self.startEventTap()
            } else {
                self.autoscrollEngine?.forceStop()
                self.stopEventTap()
            }
        }
    }

    @MainActor
    func restartListeners() {
        logger.info("Restarting tiffy-click listeners...")
        autoscrollEngine?.forceStop()
        stopMultitouchDevices()
        stopEventTap()

        guard isUserSessionActive else { return }

        registerMultitouchDevices()
        if SystemPermissions.isAccessibilityGranted(prompt: false) {
            _ = startEventTap()
        }
    }

    func scheduleRestart(delay: TimeInterval, reason: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isUserSessionActive else { return }
            logger.info("Scheduling restart (\(reason)) in \(delay)s")
            self.restartTimer?.invalidate()
            self.restartTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.restartListeners()
                }
            }
        }
    }

    // MARK: - Multitouch Callback

    private static let multitouchCallback: MTFrameCallbackFunction = { _, data, nFingers, _, _ in
        InputController.shared.handleMultitouchFrame(data: data, count: Int(nFingers))
    }

    private func handleMultitouchFrame(data: UnsafePointer<MTTouch>?, count: Int) {
        let config = TiffyClickConfig.shared.snapshot
        guard config.isEnabled else {
            stateLock.lock()
            isTargetFingersDown = false
            stateLock.unlock()
            return
        }

        if let bundleID = AppInspector.frontmostBundleID(),
           config.ignoredAppBundles.contains(bundleID) {
            stateLock.lock()
            isTargetFingersDown = false
            stateLock.unlock()
            return
        }

        var points: [NormalizedTouchPoint] = []
        if let data, count > 0 {
            points.reserveCapacity(count)
            for touch in UnsafeBufferPointer(start: data, count: count) {
                points.append(
                    NormalizedTouchPoint(
                        x: touch.normalizedVector.position.x,
                        y: touch.normalizedVector.position.y
                    )
                )
            }
        }

        let now = ProcessInfo.processInfo.systemUptime
        stateLock.lock()
        let result = tapRecognizer.processFrame(touches: points, timestamp: now, config: config)
        isTargetFingersDown = result.isTargetFingerCountActive
        stateLock.unlock()

        if result.shouldTriggerTapMiddleClick {
            handleTapMiddleClick(config: config)
        }
    }

    private func handleTapMiddleClick(config: ConfigSnapshot) {
        let location = CGEvent(source: nil)?.location ?? .zero
        let frontmost = AppInspector.frontmostBundleID()
        let autoscrollAllowed = config.autoscrollMode == .smart
            && !(frontmost.map { config.autoscrollIgnoredBundles.contains($0) } ?? false)

        if autoscrollAllowed, let engine = autoscrollEngine {
            // If already scrolling, tap cancels it
            if engine.isActive {
                engine.forceStop()
                return
            }
            // In Smart mode, tapping on non-link empty page toggles Autoscroll!
            let swallowedDown = engine.handleMiddleDown(at: location, config: config)
            if swallowedDown {
                _ = engine.handleMiddleUp(at: location, config: config)
                return
            }
        }

        AutoscrollEngine.postSyntheticMiddleClick(at: location)
    }

    private func registerMultitouchDevices() {
        stopMultitouchDevices()
        currentDevices = MTDevice.createList()
        for device in currentDevices {
            device.registerAndStart(Self.multitouchCallback)
        }
    }

    private func stopMultitouchDevices() {
        for device in currentDevices {
            device.unregisterAndStop(Self.multitouchCallback)
        }
        currentDevices.removeAll()
    }

    // MARK: - CGEventTap

    @discardableResult
    private func startEventTap() -> Bool {
        if let tap = eventTap, CFMachPortIsValid(tap), runLoopSource != nil {
            CGEvent.tapEnable(tap: tap, enable: true)
            return true
        }
        stopEventTap()

        let mask: CGEventMask = [
            CGEventType.leftMouseDown,
            .leftMouseDragged,
            .leftMouseUp,
            .rightMouseDown,
            .rightMouseDragged,
            .rightMouseUp,
            .otherMouseDown,
            .otherMouseDragged,
            .otherMouseUp,
            .mouseMoved,
            .keyDown
        ].reduce(0) { $0 | (1 << $1.rawValue) }

        let callback: CGEventTapCallBack = { _, type, event, _ in
            InputController.shared.handleCGEvent(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: nil
        ) else {
            logger.error("Failed to create CGEventTap (Accessibility permission required)")
            return false
        }

        guard let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = src
        logger.info("CGEventTap started successfully")
        return true
    }

    private func stopEventTap() {
        guard let tap = eventTap else { return }
        if CFMachPortIsValid(tap) {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            }
            CFMachPortInvalidate(tap)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleCGEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable automatically if macOS disables the tap due to timeout
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // Never intercept our own synthetic events
        if event.getIntegerValueField(.eventSourceUserData) == kTiffySyntheticEventTag {
            return Unmanaged.passUnretained(event)
        }

        let config = TiffyClickConfig.shared.snapshot
        guard config.isEnabled else {
            return Unmanaged.passUnretained(event)
        }

        let frontmost = AppInspector.frontmostBundleID()
        if let frontmost, config.ignoredAppBundles.contains(frontmost) {
            return Unmanaged.passUnretained(event)
        }

        let autoscrollAllowed = config.autoscrollMode != .off
            && !(frontmost.map { config.autoscrollIgnoredBundles.contains($0) } ?? false)

        // Escape cancels active Toggle Autoscroll
        if type == .keyDown {
            if event.getIntegerValueField(.keyboardEventKeycode) == Self.kEscapeKeyCode,
               autoscrollEngine.handleCancelTrigger() {
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        // Track cursor position for active or pending Autoscroll
        if type == .mouseMoved || type == .leftMouseDragged || type == .rightMouseDragged || type == .otherMouseDragged {
            autoscrollEngine.handleCursorMove(to: event.location, config: config)
        }

        // 1. Trackpad Multi-Finger Click & Middle-Drag conversion
        if type == .leftMouseDown || type == .rightMouseDown {
            stateLock.lock()
            let fingersReady = isTargetFingersDown
            if fingersReady {
                convertedDragActive = true
                isTargetFingersDown = false
                tapRecognizer.recordNaturalMiddleClick(at: ProcessInfo.processInfo.systemUptime)
            }
            stateLock.unlock()

            if fingersReady {
                if autoscrollAllowed && autoscrollEngine.handleMiddleDown(at: event.location, config: config) {
                    return nil
                }
                event.type = .otherMouseDown
                event.setIntegerValueField(.mouseEventButtonNumber, value: Self.kCenterButton)
                return Unmanaged.passUnretained(event)
            } else {
                // Normal left/right click cancels active toggle autoscroll
                if autoscrollEngine.handleCancelTrigger() {
                    return nil
                }
                return Unmanaged.passUnretained(event)
            }
        }

        if type == .leftMouseDragged || type == .rightMouseDragged {
            stateLock.lock()
            let isConverted = convertedDragActive
            stateLock.unlock()

            if isConverted {
                if autoscrollEngine.isActive {
                    return nil
                }
                // Proper Middle-Drag support!
                event.type = .otherMouseDragged
                event.setIntegerValueField(.mouseEventButtonNumber, value: Self.kCenterButton)
                return Unmanaged.passUnretained(event)
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .leftMouseUp || type == .rightMouseUp {
            stateLock.lock()
            let isConverted = convertedDragActive
            if isConverted {
                convertedDragActive = false
            }
            stateLock.unlock()

            if isConverted {
                if autoscrollAllowed && autoscrollEngine.handleMiddleUp(at: event.location, config: config) {
                    return nil
                }
                event.type = .otherMouseUp
                event.setIntegerValueField(.mouseEventButtonNumber, value: Self.kCenterButton)
                return Unmanaged.passUnretained(event)
            }
            return Unmanaged.passUnretained(event)
        }

        // 2. Physical Mouse Middle Button -> Universal Autoscroll
        if config.autoscrollForPhysicalMouse && autoscrollAllowed {
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            if button == Self.kCenterButton {
                switch type {
                case .otherMouseDown:
                    if autoscrollEngine.handleMiddleDown(at: event.location, config: config) {
                        return nil
                    }
                case .otherMouseDragged:
                    if autoscrollEngine.isActive {
                        return nil
                    }
                case .otherMouseUp:
                    if autoscrollEngine.handleMiddleUp(at: event.location, config: config) {
                        return nil
                    }
                default:
                    break
                }
            }
        }

        return Unmanaged.passUnretained(event)
    }

    // MARK: - System Lifecycle Resilience

    private func observeSystemEvents() {
        let wsnc = NSWorkspace.shared.notificationCenter

        wsnc.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleRestart(delay: 6.0, reason: "System woke from sleep")
        }

        wsnc.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.isUserSessionActive = false
            self.restartTimer?.invalidate()
            self.autoscrollEngine?.forceStop()
            self.stopMultitouchDevices()
            self.stopEventTap()
        }

        wsnc.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.isUserSessionActive = true
            Task { @MainActor in
                self.restartListeners()
            }
        }

        wsnc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Cancel toggle autoscroll cleanly when switching apps
            self?.autoscrollEngine?.forceStop()
        }

        CGDisplayRegisterReconfigurationCallback({ _, flags, _ in
            if flags.contains(.setModeFlag) || flags.contains(.addFlag) || flags.contains(.removeFlag) {
                InputController.shared.scheduleRestart(delay: 2.0, reason: "Display reconfigured")
            }
        }, nil)
    }
}
