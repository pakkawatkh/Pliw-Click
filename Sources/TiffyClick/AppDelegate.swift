import AppKit
import ServiceManagement
import SwiftUI
import TiffyClickCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let config = TiffyClickConfig.shared
    private let accessibilityMonitor = AccessibilityMonitor()
    private let overlayController = AutoscrollOverlayController()
    private let updater = UpdateChecker.shared

    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?

    private var permissionStatusItem: NSMenuItem!
    private var permissionActionItem: NSMenuItem!
    private var permissionSeparator: NSMenuItem!
    private var enabledItem: NSMenuItem!
    private var autoscrollToggleItem: NSMenuItem!
    private var tapToClickItem: NSMenuItem!
    private var fingersMenuItem: NSMenuItem!
    private var fingerOptionItems: [Int: NSMenuItem] = [:]
    private var allowMoreFingersItem: NSMenuItem!
    private var currentAppMenuItem: NSMenuItem!
    private var ignoreAutoscrollItem: NSMenuItem!
    private var ignoreAppItem: NSMenuItem!
    private var settingsMenuItem: NSMenuItem!
    private var restartMenuItem: NSMenuItem!
    private var languageMenuItem: NSMenuItem!
    private var langThItem: NSMenuItem!
    private var langEnItem: NSMenuItem!
    private var updateMenuItem: NSMenuItem!
    private var versionMenuItem: NSMenuItem!
    private var quitMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()

        InputController.shared.configure(overlay: overlayController)
        InputController.shared.start(accessibilityMonitor: accessibilityMonitor)

        accessibilityMonitor.addListener { [weak self] trusted in
            self?.updatePermissionUI(trusted: trusted)
        }
        accessibilityMonitor.start()

        updater.checkForUpdates(silent: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem.isVisible = true
        openSettings()
        return true
    }

    // MARK: - Menu Bar Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.behavior = .removalAllowed

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: "tiffy-click")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "tiffy-click"
        }

        let menu = NSMenu()
        menu.delegate = self

        // Accessibility warning banner (hidden once granted)
        permissionStatusItem = menu.addItem(withTitle: "", action: nil, keyEquivalent: "")
        permissionStatusItem.image = symbol("exclamationmark.triangle")
        permissionActionItem = menu.addItem(withTitle: "", action: #selector(openAccessibility), keyEquivalent: "")
        permissionActionItem.target = self
        permissionActionItem.image = symbol("lock.shield")
        permissionSeparator = NSMenuItem.separator()
        menu.addItem(permissionSeparator)

        // Core toggles
        enabledItem = menu.addItem(withTitle: "", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self

        autoscrollToggleItem = menu.addItem(withTitle: "", action: #selector(toggleAutoscroll), keyEquivalent: "")
        autoscrollToggleItem.target = self

        menu.addItem(.separator())

        // Trackpad & per-app controls
        tapToClickItem = menu.addItem(withTitle: "", action: #selector(toggleTapToClick), keyEquivalent: "")
        tapToClickItem.target = self

        fingersMenuItem = menu.addItem(withTitle: "", action: nil, keyEquivalent: "")
        fingersMenuItem.image = symbol("hand.tap")
        let fingersSubmenu = NSMenu()
        for count in 2...10 {
            let item = fingersSubmenu.addItem(withTitle: "\(count)", action: #selector(selectFingerCount(_:)), keyEquivalent: "")
            item.tag = count
            item.target = self
            fingerOptionItems[count] = item
        }
        fingersSubmenu.addItem(.separator())
        allowMoreFingersItem = fingersSubmenu.addItem(withTitle: "", action: #selector(toggleAllowMoreFingers), keyEquivalent: "")
        allowMoreFingersItem.target = self
        fingersMenuItem.submenu = fingersSubmenu

        currentAppMenuItem = menu.addItem(withTitle: "", action: nil, keyEquivalent: "")
        currentAppMenuItem.image = symbol("macwindow")
        let currentAppSubmenu = NSMenu()
        ignoreAutoscrollItem = currentAppSubmenu.addItem(withTitle: "", action: #selector(toggleIgnoreAutoscroll), keyEquivalent: "")
        ignoreAutoscrollItem.target = self
        ignoreAppItem = currentAppSubmenu.addItem(withTitle: "", action: #selector(toggleIgnoreApp), keyEquivalent: "")
        ignoreAppItem.target = self
        currentAppMenuItem.submenu = currentAppSubmenu

        menu.addItem(.separator())

        // App controls
        settingsMenuItem = menu.addItem(withTitle: "", action: #selector(openSettings), keyEquivalent: ",")
        settingsMenuItem.target = self
        settingsMenuItem.image = symbol("gearshape")

        // Option-key alternate for power users (keeps menu minimal!)
        restartMenuItem = menu.addItem(withTitle: "", action: #selector(restartListeners), keyEquivalent: ",")
        restartMenuItem.keyEquivalentModifierMask = [.command, .option]
        restartMenuItem.isAlternate = true
        restartMenuItem.target = self
        restartMenuItem.image = symbol("arrow.clockwise")

        languageMenuItem = menu.addItem(withTitle: "", action: nil, keyEquivalent: "")
        languageMenuItem.image = symbol("globe")
        let langSubmenu = NSMenu()
        langThItem = langSubmenu.addItem(withTitle: "ไทย", action: #selector(selectThai), keyEquivalent: "")
        langThItem.target = self
        langEnItem = langSubmenu.addItem(withTitle: "English", action: #selector(selectEnglish), keyEquivalent: "")
        langEnItem.target = self
        languageMenuItem.submenu = langSubmenu

        updateMenuItem = menu.addItem(withTitle: "", action: #selector(checkUpdates), keyEquivalent: "")
        updateMenuItem.target = self
        updateMenuItem.image = symbol("arrow.down.circle")

        menu.addItem(.separator())

        versionMenuItem = menu.addItem(withTitle: "tiffy-click \(updater.currentVersion)", action: nil, keyEquivalent: "")
        versionMenuItem.isEnabled = false

        quitMenuItem = menu.addItem(withTitle: "", action: #selector(quitApp), keyEquivalent: "q")
        quitMenuItem.target = self

        statusItem.menu = menu
        refreshLocalizedMenuTitles()
    }

    private func symbol(_ name: String) -> NSImage? {
        let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        img?.isTemplate = true
        return img
    }

    private func refreshLocalizedMenuTitles() {
        let lang = config.language
        permissionStatusItem.title = L10n.t("ต้องการสิทธิ์การช่วยการเข้าถึง", "Accessibility Required", lang: lang)
        permissionActionItem.title = L10n.t("เปิดการตั้งค่าความเป็นส่วนตัว…", "Open Privacy Settings…", lang: lang)

        enabledItem.title = L10n.t("เปิดใช้งาน", "Enabled", lang: lang)
        autoscrollToggleItem.title = L10n.t("เลื่อนอัตโนมัติ (Autoscroll)", "Autoscroll", lang: lang)
        tapToClickItem.title = L10n.t("แตะเพื่อคลิกกลาง", "Tap to Click", lang: lang)

        let plus = config.allowMoreFingers ? "+" : ""
        fingersMenuItem.title = L10n.t(
            "จำนวนนิ้ว (\(config.minimumFingers)\(plus))",
            "Fingers (\(config.minimumFingers)\(plus))",
            lang: lang
        )
        for count in 2...10 {
            if let item = fingerOptionItems[count] {
                item.title = L10n.t("\(count) นิ้ว", "\(count) Fingers", lang: lang)
                item.state = config.minimumFingers == count ? .on : .off
            }
        }
        allowMoreFingersItem.title = L10n.t(
            "รองรับ \(config.minimumFingers) นิ้วขึ้นไป",
            "Allow \(config.minimumFingers)+ Fingers",
            lang: lang
        )
        allowMoreFingersItem.state = config.allowMoreFingers ? .on : .off

        settingsMenuItem.title = L10n.t("การตั้งค่า…", "Settings…", lang: lang)
        restartMenuItem.title = L10n.t("รีสตาร์ทตัวจับนิ้ว", "Restart Listeners", lang: lang)
        languageMenuItem.title = L10n.t("ภาษา", "Language", lang: lang)
        updateMenuItem.title = L10n.t("ตรวจหาอัปเดต…", "Check for Updates…", lang: lang)
        quitMenuItem.title = L10n.t("ออกจาก tiffy-click", "Quit tiffy-click", lang: lang)

        langThItem.state = lang == .th ? .on : .off
        langEnItem.state = lang == .en ? .on : .off
    }

    private func updatePermissionUI(trusted: Bool) {
        statusItem.button?.appearsDisabled = !trusted
        permissionStatusItem.isHidden = trusted
        permissionActionItem.isHidden = trusted
        permissionSeparator.isHidden = trusted
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshLocalizedMenuTitles()

        enabledItem.state = config.isEnabled ? .on : .off
        autoscrollToggleItem.state = config.autoscrollEnabled ? .on : .off
        tapToClickItem.state = config.tapToClick ? .on : .off

        let lang = config.language
        if let app = AppInspector.frontmostApp(), let name = app.localizedName, let bundleID = app.bundleIdentifier {
            currentAppMenuItem.title = name
            currentAppMenuItem.isHidden = false

            ignoreAutoscrollItem.title = L10n.t("ปิด Autoscroll ในแอปนี้", "Pause Autoscroll", lang: lang)
            ignoreAutoscrollItem.state = config.autoscrollIgnoredBundles.contains(bundleID) ? .on : .off

            ignoreAppItem.title = L10n.t("ยกเว้นแอปนี้ทั้งหมด", "Ignore App", lang: lang)
            ignoreAppItem.state = config.ignoredAppBundles.contains(bundleID) ? .on : .off
        } else {
            currentAppMenuItem.isHidden = true
        }
    }

    // MARK: - Actions

    @objc private func openAccessibility() {
        SystemPermissions.openAccessibilitySettings()
    }

    @objc private func toggleEnabled() {
        config.isEnabled.toggle()
    }

    @objc private func toggleAutoscroll() {
        config.autoscrollEnabled.toggle()
    }

    @objc private func selectThai() {
        config.language = .th
    }

    @objc private func selectEnglish() {
        config.language = .en
    }

    @objc private func toggleTapToClick() {
        config.tapToClick.toggle()
    }

    @objc private func selectFingerCount(_ sender: NSMenuItem) {
        config.minimumFingers = max(2, min(10, sender.tag))
    }

    @objc private func toggleAllowMoreFingers() {
        config.allowMoreFingers.toggle()
    }

    @objc private func toggleIgnoreApp() {
        guard let bundleID = AppInspector.frontmostBundleID() else { return }
        config.toggleIgnoredApp(bundleID)
    }

    @objc private func toggleIgnoreAutoscroll() {
        guard let bundleID = AppInspector.frontmostBundleID() else { return }
        config.toggleAutoscrollIgnoredApp(bundleID)
    }

    @objc private func restartListeners() {
        InputController.shared.restartListeners()
    }

    @objc private func checkUpdates() {
        updater.checkForUpdates(silent: false)
    }

    @objc private func openSettings() {
        let lang = config.language
        if let window = settingsWindow {
            window.title = L10n.t("การตั้งค่า tiffy-click", "tiffy-click Settings", lang: lang)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = SettingsView(
            config: config,
            accessibilityMonitor: accessibilityMonitor,
            updater: updater
        )
        let hosting = NSHostingController(rootView: rootView)

        let window = NSWindow(contentViewController: hosting)
        window.title = L10n.t("การตั้งค่า tiffy-click", "tiffy-click Settings", lang: lang)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
        self.settingsWindow = window
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
