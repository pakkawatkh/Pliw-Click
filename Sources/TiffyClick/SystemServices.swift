import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import os.log
import TiffyClickCore

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

    /// Determines whether Autoscroll should activate at `cgPoint`.
    /// When `browsersOnly` is true (default), Autoscroll activates ONLY on empty, scrollable webpage areas
    /// inside a web browser — everywhere else (desktop, non-browser apps, browser tabs/toolbars, links,
    /// buttons, text inputs, non-scrollable pages) behaves as a normal middle click.
    static func canActivateAutoscroll(at cgPoint: CGPoint, bundleID: String?, browsersOnly: Bool) -> Bool {
        if browsersOnly {
            guard BrowserRegistry.isBrowser(bundleID: bundleID) else {
                return false
            }
            return isScrollableEmptyWebArea(at: cgPoint)
        } else {
            return !isInteractiveMiddleClickTarget(at: cgPoint)
        }
    }

    /// Checks via macOS Accessibility whether `cgPoint` is inside a scrollable, non-interactive `AXWebArea`.
    private static func isScrollableEmptyWebArea(at cgPoint: CGPoint) -> Bool {
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
            "AXTextField",
            "AXTextArea",
            "AXComboBox",
            "AXPopUpButton",
            "AXMenuItem",
            "AXMenuBarItem",
            "AXCheckBox",
            "AXSlider",
            "AXToolbar",
            "AXTabGroup",
            "AXScrollBar"
        ]
        let interactiveSubroles: Set<String> = [
            "AXTabButton",
            "AXCloseButton",
            "AXLink",
            "AXSearchField"
        ]

        var webArea: AXUIElement?
        var scrollArea: AXUIElement?

        for _ in 0..<18 {
            let role = axStringAttribute(current, kAXRoleAttribute)
            let subrole = axStringAttribute(current, kAXSubroleAttribute)

            if webArea == nil {
                if let role, interactiveRoles.contains(role) {
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
                webArea = current
            } else if role == "AXScrollArea" {
                scrollArea = current
                if webArea != nil {
                    break
                }
            } else if role == "AXWindow" || role == "AXApplication" {
                break
            }

            guard let parent = axParent(of: current) else { break }
            current = parent
        }

        // Must be inside an actual webpage viewport (never browser tabs/toolbar/bookmarks)
        guard let webArea else { return false }

        // Check scrollability if enclosing AXScrollArea exposes scrollbars or frame dimensions
        if let scrollArea {
            if hasAttribute(scrollArea, kAXVerticalScrollBarAttribute)
                || hasAttribute(scrollArea, kAXHorizontalScrollBarAttribute) {
                return true
            }
            if let webSize = axSizeAttribute(webArea),
               let scrollSize = axSizeAttribute(scrollArea) {
                return webSize.height > scrollSize.height + 2 || webSize.width > scrollSize.width + 2
            }
        }

        // Fallback: if browser hides scrollArea attributes (e.g. certain Chromium/Arc builds),
        // allow autoscroll inside non-interactive AXWebArea
        return true
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

    private static func axSizeAttribute(_ element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value) == .success,
              let raw = value,
              CFGetTypeID(raw) == AXValueGetTypeID() else {
            return nil
        }
        var size = CGSize.zero
        if AXValueGetValue(raw as! AXValue, .cgSize, &size) {
            return size
        }
        return nil
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
