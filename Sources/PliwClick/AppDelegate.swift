import AppKit
import ServiceManagement
import SwiftUI
import PliwClickCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let config = PliwClickConfig.shared
    private let accessibilityMonitor = AccessibilityMonitor()
    private let overlayController = AutoscrollOverlayController()
    private let updater = UpdateChecker.shared
    private let popoverViewModel = StatusPopoverViewModel()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?

    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()

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
            let image = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: "Pliw Click")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Pliw Click"
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }
    }

    private func setupPopover() {
        let rootView = StatusPopoverView(
            config: config,
            accessibilityMonitor: accessibilityMonitor,
            viewModel: popoverViewModel,
            currentVersion: updater.currentVersion,
            onOpenAccessibility: { [weak self] in
                self?.closePopover()
                self?.openAccessibility()
            },
            onRestartListeners: { [weak self] in
                self?.restartListeners()
            },
            onOpenSettings: { [weak self] in
                self?.closePopover()
                self?.openSettings()
            },
            onCheckUpdates: { [weak self] in
                self?.closePopover()
                self?.checkUpdates()
            },
            onQuit: { [weak self] in
                self?.quitApp()
            }
        )

        let hosting = NSHostingController(rootView: rootView)
        hosting.sizingOptions = [.preferredContentSize]

        let pop = NSPopover()
        pop.contentViewController = hosting
        pop.behavior = .applicationDefined
        pop.animates = true
        pop.delegate = self
        self.popover = pop
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popoverViewModel.refreshFrontmostApp()
        popoverViewModel.isOptionPressed = NSEvent.modifierFlags.contains(.option)
        popoverViewModel.expandedSection = nil

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        installEventMonitors()
    }

    private func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
        removeEventMonitors()
    }

    func popoverDidClose(_ notification: Notification) {
        removeEventMonitors()
    }

    private func installEventMonitors() {
        removeEventMonitors()

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .flagsChanged]
        ) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self, self.popover.isShown else { return }
                if event.type == .flagsChanged {
                    self.popoverViewModel.isOptionPressed = event.modifierFlags.contains(.option)
                } else {
                    self.closePopover()
                }
            }
        }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown, .flagsChanged]
        ) { [weak self] event in
            guard let self, self.popover.isShown else { return event }

            switch event.type {
            case .flagsChanged:
                self.popoverViewModel.isOptionPressed = event.modifierFlags.contains(.option)
                return event

            case .keyDown:
                if event.keyCode == 53 { // Escape
                    self.closePopover()
                    return nil
                }
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                if flags == .command {
                    if event.charactersIgnoringModifiers == "," {
                        self.closePopover()
                        self.openSettings()
                        return nil
                    }
                    if event.charactersIgnoringModifiers?.lowercased() == "q" {
                        self.quitApp()
                        return nil
                    }
                }
                return event

            case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                let popoverWindow = self.popover.contentViewController?.view.window
                let statusWindow = self.statusItem.button?.window
                if event.window !== popoverWindow && event.window !== statusWindow {
                    self.closePopover()
                }
                return event

            default:
                return event
            }
        }
    }

    private func removeEventMonitors() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }

    private func updatePermissionUI(trusted: Bool) {
        statusItem.button?.appearsDisabled = !trusted
    }

    // MARK: - Actions

    @objc private func openAccessibility() {
        SystemPermissions.openAccessibilitySettings()
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
            window.title = L10n.t("การตั้งค่า Pliw Click", "Pliw Click Settings", lang: lang)
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
        window.title = L10n.t("การตั้งค่า Pliw Click", "Pliw Click Settings", lang: lang)
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
