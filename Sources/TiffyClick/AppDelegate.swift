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
    private var enabledItem: NSMenuItem!
    private var modeHeaderItem: NSMenuItem!
    private var ignoreAppItem: NSMenuItem!
    private var ignoreAutoscrollItem: NSMenuItem!
    private var smartModeItem: NSMenuItem!
    private var holdModeItem: NSMenuItem!
    private var offModeItem: NSMenuItem!
    private var fingersMenuItem: NSMenuItem!
    private var fingerOptionItems: [Int: NSMenuItem] = [:]
    private var allowMoreFingersItem: NSMenuItem!
    private var tapToClickItem: NSMenuItem!
    private var settingsMenuItem: NSMenuItem!
    private var restartMenuItem: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!
    private var updateMenuItem: NSMenuItem!
    private var languageMenuItem: NSMenuItem!
    private var langThItem: NSMenuItem!
    private var langEnItem: NSMenuItem!
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
            button.toolTip = "tiffy-click — Middle Click & Universal Autoscroll"
        }

        let menu = NSMenu()
        menu.delegate = self

        permissionStatusItem = menu.addItem(withTitle: "", action: nil, keyEquivalent: "")
        permissionActionItem = menu.addItem(withTitle: "", action: #selector(openAccessibility), keyEquivalent: "")
        permissionActionItem.target = self
        menu.addItem(.separator())

        enabledItem = menu.addItem(withTitle: "", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        menu.addItem(.separator())

        modeHeaderItem = menu.addItem(withTitle: "", action: nil, keyEquivalent: "")
        modeHeaderItem.isEnabled = false

        smartModeItem = menu.addItem(withTitle: "", action: #selector(selectSmartMode), keyEquivalent: "")
        smartModeItem.target = self
        holdModeItem = menu.addItem(withTitle: "", action: #selector(selectHoldMode), keyEquivalent: "")
        holdModeItem.target = self
        offModeItem = menu.addItem(withTitle: "", action: #selector(selectOffMode), keyEquivalent: "")
        offModeItem.target = self
        menu.addItem(.separator())

        tapToClickItem = menu.addItem(withTitle: "", action: #selector(toggleTapToClick), keyEquivalent: "")
        tapToClickItem.target = self

        fingersMenuItem = menu.addItem(withTitle: "", action: nil, keyEquivalent: "")
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

        ignoreAutoscrollItem = menu.addItem(withTitle: "", action: #selector(toggleIgnoreAutoscroll), keyEquivalent: "")
        ignoreAutoscrollItem.target = self

        ignoreAppItem = menu.addItem(withTitle: "", action: #selector(toggleIgnoreApp), keyEquivalent: "")
        ignoreAppItem.target = self
        menu.addItem(.separator())

        settingsMenuItem = menu.addItem(withTitle: "", action: #selector(openSettings), keyEquivalent: ",")
        settingsMenuItem.target = self

        restartMenuItem = menu.addItem(withTitle: "", action: #selector(restartListeners), keyEquivalent: "r")
        restartMenuItem.target = self

        languageMenuItem = menu.addItem(withTitle: "Language / ภาษา", action: nil, keyEquivalent: "")
        let langSubmenu = NSMenu()
        langThItem = langSubmenu.addItem(withTitle: "ไทย (Thai)", action: #selector(selectThai), keyEquivalent: "")
        langThItem.target = self
        langEnItem = langSubmenu.addItem(withTitle: "English", action: #selector(selectEnglish), keyEquivalent: "")
        langEnItem.target = self
        languageMenuItem.submenu = langSubmenu

        launchAtLoginItem = menu.addItem(withTitle: "", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self

        updateMenuItem = menu.addItem(withTitle: "", action: #selector(checkUpdates), keyEquivalent: "")
        updateMenuItem.target = self

        menu.addItem(.separator())
        let versionItem = menu.addItem(withTitle: "tiffy-click v\(updater.currentVersion)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false

        quitMenuItem = menu.addItem(withTitle: "", action: #selector(quitApp), keyEquivalent: "q")
        quitMenuItem.target = self

        statusItem.menu = menu
        refreshLocalizedMenuTitles()
    }

    private func refreshLocalizedMenuTitles() {
        let lang = config.language
        permissionStatusItem.title = L10n.t("⚠️ ยังไม่ได้อนุญาต Accessibility", "⚠️ Missing Accessibility Permission", lang: lang)
        permissionActionItem.title = L10n.t("เปิดการตั้งค่า Accessibility...", "Open Accessibility Settings...", lang: lang)
        enabledItem.title = L10n.t("เปิดใช้งาน tiffy-click", "Enable tiffy-click", lang: lang)
        modeHeaderItem.title = L10n.t("โหมด Autoscroll (Hold Scroll)", "Autoscroll Mode (Hold Scroll)", lang: lang)
        smartModeItem.title = "  " + AutoscrollMode.smart.displayName(lang: lang)
        holdModeItem.title = "  " + AutoscrollMode.holdOnly.displayName(lang: lang)
        offModeItem.title = "  " + AutoscrollMode.off.displayName(lang: lang)
        tapToClickItem.title = L10n.t("Tap \(config.minimumFingers) นิ้วเพื่อคลิกกลาง", "Tap \(config.minimumFingers) Fingers to Middle Click", lang: lang)
        let plusSuffix = config.allowMoreFingers ? "+" : ""
        fingersMenuItem.title = L10n.t("จำนวนนิ้ว: \(config.minimumFingers)\(plusSuffix) นิ้ว", "Finger Count: \(config.minimumFingers)\(plusSuffix) Fingers", lang: lang)
        for count in 2...10 {
            if let item = fingerOptionItems[count] {
                item.title = L10n.t("\(count) นิ้ว", "\(count) Fingers", lang: lang)
                item.state = config.minimumFingers == count ? .on : .off
            }
        }
        allowMoreFingersItem.title = L10n.t("รองรับนิ้วมากกว่าที่กำหนด (\(config.minimumFingers)+ นิ้ว)", "Allow More Fingers (\(config.minimumFingers)+)", lang: lang)
        allowMoreFingersItem.state = config.allowMoreFingers ? .on : .off
        settingsMenuItem.title = L10n.t("ตั้งค่า (Settings)...", "Settings...", lang: lang)
        restartMenuItem.title = L10n.t("รีสตาร์ทตัวจับนิ้ว (Restart)", "Restart Listeners", lang: lang)
        launchAtLoginItem.title = L10n.t("เปิดอัตโนมัติเมื่อเปิดเครื่อง", "Launch at Login", lang: lang)
        updateMenuItem.title = L10n.t("ตรวจสอบอัปเดต...", "Check for Updates...", lang: lang)
        quitMenuItem.title = L10n.t("ออกจาก tiffy-click", "Quit tiffy-click", lang: lang)
        langThItem.state = lang == .th ? .on : .off
        langEnItem.state = lang == .en ? .on : .off
    }

    private func updatePermissionUI(trusted: Bool) {
        statusItem.button?.appearsDisabled = !trusted
        permissionStatusItem.isHidden = trusted
        permissionActionItem.isHidden = trusted
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshLocalizedMenuTitles()

        enabledItem.state = config.isEnabled ? .on : .off
        smartModeItem.state = config.autoscrollMode == .smart ? .on : .off
        holdModeItem.state = config.autoscrollMode == .holdOnly ? .on : .off
        offModeItem.state = config.autoscrollMode == .off ? .on : .off

        tapToClickItem.state = config.tapToClick ? .on : .off
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off

        let lang = config.language
        if let app = AppInspector.frontmostApp(), let name = app.localizedName, let bundleID = app.bundleIdentifier {
            ignoreAppItem.title = L10n.t("ยกเว้น \(name) ทั้งหมด", "Ignore \(name) Completely", lang: lang)
            ignoreAppItem.state = config.ignoredAppBundles.contains(bundleID) ? .on : .off
            ignoreAppItem.isEnabled = true

            ignoreAutoscrollItem.title = L10n.t("ปิด Autoscroll ใน \(name)", "Disable Autoscroll in \(name)", lang: lang)
            ignoreAutoscrollItem.state = config.autoscrollIgnoredBundles.contains(bundleID) ? .on : .off
            ignoreAutoscrollItem.isEnabled = true
        } else {
            ignoreAppItem.title = L10n.t("ยกเว้นแอปนี้ทั้งหมด", "Ignore Focused App", lang: lang)
            ignoreAutoscrollItem.title = L10n.t("ปิด Autoscroll สำหรับแอปนี้", "Disable Autoscroll for Focused App", lang: lang)
            ignoreAppItem.isEnabled = false
            ignoreAutoscrollItem.isEnabled = false
        }
    }

    // MARK: - Actions

    @objc private func openAccessibility() {
        SystemPermissions.openAccessibilitySettings()
    }

    @objc private func toggleEnabled() {
        config.isEnabled.toggle()
    }

    @objc private func selectSmartMode() {
        config.autoscrollMode = .smart
    }

    @objc private func selectHoldMode() {
        config.autoscrollMode = .holdOnly
    }

    @objc private func selectOffMode() {
        config.autoscrollMode = .off
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

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            logger.error("Failed to toggle Launch at Login: \(error.localizedDescription)")
        }
    }

    @objc private func checkUpdates() {
        updater.checkForUpdates(silent: false)
    }

    @objc private func openSettings() {
        if let window = settingsWindow {
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
        window.title = "tiffy-click Settings"
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
