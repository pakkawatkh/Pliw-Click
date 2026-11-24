import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import os.log

let logger = Logger(subsystem: "com.local.tiffy-click", category: "TiffyClick")

enum SystemPermissions {
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

        // Walk up to 4 levels to catch text nodes nested inside AXLink or AXTab
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

        for _ in 0..<4 {
            var roleVal: CFTypeRef?
            if AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &roleVal) == .success,
               let role = roleVal as? String {
                if interactiveRoles.contains(role) {
                    return true
                }
                // Stop walking once we hit a web area or scroll area container
                if role == "AXWebArea" || role == "AXScrollArea" || role == "AXWindow" {
                    return false
                }
            }

            var subroleVal: CFTypeRef?
            if AXUIElementCopyAttributeValue(current, kAXSubroleAttribute as CFString, &subroleVal) == .success,
               let subrole = subroleVal as? String,
               interactiveSubroles.contains(subrole) {
                return true
            }

            // Check if element has an AXURL attribute (common for links in Electron/Chromium)
            var urlVal: CFTypeRef?
            if AXUIElementCopyAttributeValue(current, "AXURL" as CFString, &urlVal) == .success,
               urlVal != nil {
                // Only treat as link if not the whole AXWebArea (checked above)
                return true
            }

            var parentVal: CFTypeRef?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parentVal) == .success,
                  let parent = parentVal,
                  CFGetTypeID(parent) == AXUIElementGetTypeID() else {
                break
            }
            current = parent as! AXUIElement
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
