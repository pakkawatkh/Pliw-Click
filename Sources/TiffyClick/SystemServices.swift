import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import os.log
import TiffyClickCore

let logger = Logger(subsystem: "com.local.tiffy-click", category: "TiffyClick")

enum SystemPermissions {
    private static let axQueueLock = NSLock()
    private static var enhancedAXEnabledPIDs: Set<pid_t> = []

    static func isAccessibilityGranted(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func isThreeFingerDragEnabled() -> Bool {
        CFPreferencesGetAppBooleanValue(
            "TrackpadThreeFingerDrag" as CFString,
            "com.apple.driver.AppleBluetoothMultitouch.trackpad" as CFString,
            nil
        )
    }

    static func isThreeFingerTapEnabled() -> Bool {
        CFPreferencesGetAppBooleanValue(
            "TrackpadThreeFingerTapGesture" as CFString,
            "com.apple.driver.AppleBluetoothMultitouch.trackpad" as CFString,
            nil
        )
    }

    /// Returns the bundle identifier of the application actually under `cgPoint` (even if unfocused).
    static func bundleIDAtCursor(_ cgPoint: CGPoint) -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var elementRef: AXUIElement?
        if AXUIElementCopyElementAtPosition(systemWide, Float(cgPoint.x), Float(cgPoint.y), &elementRef) == .success,
           let element = elementRef {
            var pid: pid_t = 0
            if AXUIElementGetPid(element, &pid) == .success,
               let app = NSRunningApplication(processIdentifier: pid),
               let bundleID = app.bundleIdentifier {
                return bundleID
            }
        }
        return AppInspector.frontmostBundleID()
    }

    /// Determines whether Autoscroll should activate at `cgPoint`.
    /// When `browsersOnly` is true (default), Autoscroll activates ONLY on empty webpage areas
    /// inside a web browser — everywhere else (desktop, non-browser apps, browser tabs/toolbars,
    /// links, buttons, text inputs) behaves as a normal middle click.
    static func canActivateAutoscroll(at cgPoint: CGPoint, bundleID: String?, browsersOnly: Bool) -> Bool {
        let targetBundleID = bundleIDAtCursor(cgPoint) ?? bundleID
        if browsersOnly {
            guard BrowserRegistry.isBrowser(bundleID: targetBundleID) else {
                return false
            }
            return isEmptyBrowserWebArea(at: cgPoint, bundleID: targetBundleID)
        } else {
            return !isInteractiveMiddleClickTarget(at: cgPoint)
        }
    }

    /// Checks via macOS Accessibility whether `cgPoint` is on an empty, non-interactive webpage area
    /// inside a browser (excluding tabs, toolbars, address bar, links, buttons, and inputs).
    private static func isEmptyBrowserWebArea(at cgPoint: CGPoint, bundleID: String?) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var elementRef: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(cgPoint.x), Float(cgPoint.y), &elementRef) == .success,
              let initialElement = elementRef else {
            return false
        }

        // Chromium browsers lazily disable AXWebArea until AXEnhancedUserInterface is enabled once.
        var pid: pid_t = 0
        if AXUIElementGetPid(initialElement, &pid) == .success,
           let bundleID,
           isChromiumBrowser(bundleID: bundleID) {
            let needsEnable: Bool = {
                axQueueLock.lock()
                defer { axQueueLock.unlock() }
                if enhancedAXEnabledPIDs.contains(pid) { return false }
                enhancedAXEnabledPIDs.insert(pid)
                return true
            }()
            if needsEnable {
                let appElement = AXUIElementCreateApplication(pid)
                AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
                // Re-query immediately in case Chromium populated synchronously
                var refreshed: AXUIElement?
                if AXUIElementCopyElementAtPosition(systemWide, Float(cgPoint.x), Float(cgPoint.y), &refreshed) == .success,
                   let refreshed {
                    return evaluateBrowserElement(refreshed, at: cgPoint, isChromium: true)
                }
            }
        }

        return evaluateBrowserElement(initialElement, at: cgPoint, isChromium: bundleID.map(isChromiumBrowser) ?? false)
    }

    private static func evaluateBrowserElement(_ startElement: AXUIElement, at cgPoint: CGPoint, isChromium: Bool) -> Bool {
        let interactiveOrChromeRoles: Set<String> = [
            "AXLink",
            "AXTab",
            "AXTabButton",
            "AXRadioButton",
            "AXButton",
            "AXTextField",
            "AXTextArea",
            "AXComboBox",
            "AXPopUpButton",
            "AXMenuItem",
            "AXMenuBarItem",
            "AXMenuBar",
            "AXMenu",
            "AXCheckBox",
            "AXSlider",
            "AXToolbar",
            "AXTabGroup",
            "AXScrollBar"
        ]
        let interactiveSubroles: Set<String> = [
            "AXTabButton",
            "AXCloseButton",
            "AXMinimizeButton",
            "AXZoomButton",
            "AXFullScreenButton",
            "AXLink",
            "AXSearchField"
        ]

        var current = startElement
        var foundWebArea = false
        var hitWindow: AXUIElement?

        for _ in 0..<24 {
            let role = axStringAttribute(current, kAXRoleAttribute)
            let subrole = axStringAttribute(current, kAXSubroleAttribute)

            if !foundWebArea {
                if let role, interactiveOrChromeRoles.contains(role) {
                    return false
                }
                if let subrole, interactiveSubroles.contains(subrole) {
                    return false
                }
                if role != "AXWebArea" && hasAttribute(current, "AXURL") {
                    return false
                }
            }

            if role == "AXWebArea" {
                foundWebArea = true
                break
            } else if role == "AXWindow" {
                hitWindow = current
                break
            } else if role == "AXApplication" {
                break
            }

            guard let parent = axParent(of: current) else { break }
            current = parent
        }

        if foundWebArea {
            return true
        }

        // Fallback for Chromium on the very first click before its async AXWebArea tree finishes building:
        // If we did NOT hit any toolbar/tab/button/input AND the cursor is well below the browser's top chrome (~84pt),
        // treat it as webpage content area.
        if isChromium, let window = hitWindow, let frame = axFrameAttribute(window) {
            let yOffsetFromWindowTop = cgPoint.y - frame.origin.y
            if yOffsetFromWindowTop > 88 {
                return true
            }
        }

        return false
    }

    private static func isChromiumBrowser(bundleID: String) -> Bool {
        let lower = bundleID.lowercased()
        return lower.contains("chrome")
            || lower.contains("brave")
            || lower.contains("edgemac")
            || lower.contains("thebrowser")
            || lower.contains("vivaldi")
            || lower.contains("opera")
            || lower.contains("chromium")
    }

    private static func axStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func hasAttribute(_ element: AXUIElement, _ attribute: String) -> Bool {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success && value != nil
    }

    private static func axParent(of element: AXUIElement) -> AXUIElement? {
        var parentVal: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parentVal) == .success,
              let parent = parentVal,
              CFGetTypeID(parent) == AXUIElementGetTypeID() else {
            return nil
        }
        return (parent as! AXUIElement)
    }

    private static func axFrameAttribute(_ element: AXUIElement) -> CGRect? {
        var posVal: CFTypeRef?
        var sizeVal: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posVal) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeVal) == .success,
              let pRaw = posVal, CFGetTypeID(pRaw) == AXValueGetTypeID(),
              let sRaw = sizeVal, CFGetTypeID(sRaw) == AXValueGetTypeID() else {
            return nil
        }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(pRaw as! AXValue, .cgPoint, &point),
              AXValueGetValue(sRaw as! AXValue, .cgSize, &size) else {
            return nil
        }
        return CGRect(origin: point, size: size)
    }

    /// Inspects the accessibility element under the CG screen coordinate.
    /// Returns true if the element is a link, tab, or button where standard middle-click
    /// (open link in new tab / close tab) should take precedence over Smart Autoscroll.
    static func isInteractiveMiddleClickTarget(at cgPoint: CGPoint) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var elementRef: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(systemWide, Float(cgPoint.x), Float(cgPoint.y), &elementRef)
        guard result == .success, var current = elementRef else {
            return false
        }

        let interactiveRoles: Set<String> = [
            "AXLink",
            "AXTab",
            "AXTabButton",
            "AXRadioButton",
            "AXButton",
            "AXMenuItem",
            "AXMenuBarItem"
        ]
        let interactiveSubroles: Set<String> = [
            "AXTabButton",
            "AXCloseButton",
            "AXLink"
        ]

        for _ in 0..<6 {
            let role = axStringAttribute(current, kAXRoleAttribute)
            if let role {
                if interactiveRoles.contains(role) {
                    return true
                }
                if role == "AXWebArea" || role == "AXScrollArea" || role == "AXWindow" {
                    return false
                }
            }

            if let subrole = axStringAttribute(current, kAXSubroleAttribute),
               interactiveSubroles.contains(subrole) {
                return true
            }

            if hasAttribute(current, "AXURL") {
                return true
            }

            guard let parent = axParent(of: current) else { break }
            current = parent
        }

        return false
    }
}

enum AppInspector {
    static func frontmostApp() -> NSRunningApplication? {
        NSWorkspace.shared.frontmostApplication
    }

    static func frontmostBundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}

@MainActor
final class AccessibilityMonitor: ObservableObject {
    @Published private(set) var isTrusted: Bool = false

    private var timer: Timer?
    private var hasPrompted = false
    private var listeners: [(Bool) -> Void] = []

    func addListener(_ listener: @escaping (Bool) -> Void) {
        listeners.append(listener)
    }

    func start() {
        checkNow(allowPrompt: true)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkNow(allowPrompt: Bool) {
        let shouldPrompt = allowPrompt && !hasPrompted
        let trusted = SystemPermissions.isAccessibilityGranted(prompt: shouldPrompt)
        if !trusted && shouldPrompt {
            hasPrompted = true
        }

        if trusted != isTrusted || timer == nil {
            isTrusted = trusted
            if trusted {
                hasPrompted = false
            }
            listeners.forEach { $0(trusted) }
            scheduleTimer(interval: trusted ? 4.0 : 0.75)
        }
    }

    private func scheduleTimer(interval: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkNow(allowPrompt: false)
            }
        }
    }
}
