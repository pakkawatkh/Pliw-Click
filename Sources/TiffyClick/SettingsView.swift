import AppKit
import ServiceManagement
import SwiftUI
import TiffyClickCore

struct SettingsView: View {
    @ObservedObject var config: TiffyClickConfig
    @ObservedObject var accessibilityMonitor: AccessibilityMonitor
    @ObservedObject var updater: UpdateChecker

    private var lang: AppLanguage { config.language }

    var body: some View {
        TabView {
            AutoscrollSettingsTab(config: config, accessibilityMonitor: accessibilityMonitor)
                .tabItem {
                    Label(L10n.t("Autoscroll", "Autoscroll", lang: lang), systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                }

            TrackpadSettingsTab(config: config)
                .tabItem {
                    Label(L10n.t("แทร็กแพด", "Trackpad", lang: lang), systemImage: "hand.tap")
                }

            AppsSettingsTab(config: config)
                .tabItem {
                    Label(L10n.t("แอป", "Apps", lang: lang), systemImage: "app.badge")
                }

            AboutSettingsTab(updater: updater, config: config)
                .tabItem {
                    Label(L10n.t("เกี่ยวกับ", "About", lang: lang), systemImage: "info.circle")
                }
        }
        .frame(width: 530, height: 450)
    }
}

private struct AutoscrollSettingsTab: View {
    @ObservedObject var config: TiffyClickConfig
    @ObservedObject var accessibilityMonitor: AccessibilityMonitor

    private var lang: AppLanguage { config.language }

    var body: some View {
        Form {
            if !accessibilityMonitor.isTrusted {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("ต้องการสิทธิ์ Accessibility", "Accessibility Permission Required", lang: lang))
                                .font(.headline)
                            Text(L10n.t(
                                "เปิดสิทธิ์ใน System Settings เพื่อให้ tiffy-click จับคลิกกลางและทำ Autoscroll ได้",
                                "Enable tiffy-click in System Settings to allow middle-click and universal Autoscroll.",
                                lang: lang
                            ))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(L10n.t("เปิดตั้งค่า", "Open Settings", lang: lang)) {
                            SystemPermissions.openAccessibilitySettings()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section(L10n.t("โหมด Autoscroll (Hold Scroll แบบ Windows)", "Autoscroll Mode (Windows-Style Hold Scroll)", lang: lang)) {
                Toggle(L10n.t("เปิดใช้งาน tiffy-click", "Enable tiffy-click", lang: lang), isOn: $config.isEnabled)

                Picker(L10n.t("โหมดการทำงาน", "Scroll Mode", lang: lang), selection: $config.autoscrollMode) {
                    ForEach(AutoscrollMode.allCases) { mode in
                        Text(mode.displayName(lang: lang)).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(config.autoscrollMode.descriptionText(lang: lang))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle(
                    L10n.t("ทำงานเฉพาะพื้นที่ว่างที่เลื่อนได้ในเบราว์เซอร์ (แนะนำ)", "Only on Scrollable Empty Areas in Browsers (Recommended)", lang: lang),
                    isOn: $config.autoscrollBrowsersOnly
                )

                Text(L10n.t(
                    "จุดอื่นๆ นอกเบราว์เซอร์ หรือบนลิงก์/แท็บ จะทำงานเป็นปุ่มกลางปกติ 100%",
                    "Outside browsers or on links/tabs/inputs, middle-click behaves normally.",
                    lang: lang
                ))
                .font(.caption)
                .foregroundColor(.secondary)

                Toggle(
                    L10n.t("ใช้งานกับปุ่มกลางของเมาส์จริงด้วย (Physical Mouse)", "Enable for Physical Mouse Middle Button", lang: lang),
                    isOn: $config.autoscrollForPhysicalMouse
                )
            }

            Section(L10n.t("ความเร็วและความแม่นยำ", "Speed & Precision", lang: lang)) {
                HStack {
                    Text(L10n.t("ความเร็วการเลื่อน", "Scroll Speed", lang: lang))
                    Slider(value: $config.autoscrollSpeed, in: 0.3...3.0, step: 0.1)
                    Text(String(format: "%.1fx", config.autoscrollSpeed))
                        .monospacedDigit()
                        .frame(width: 38, alignment: .trailing)
                }

                HStack {
                    Text(L10n.t("Deadzone ตรงกลาง", "Center Deadzone", lang: lang))
                    Slider(value: $config.autoscrollDeadzone, in: 4...36, step: 1)
                    Text("\(Int(config.autoscrollDeadzone)) px")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }

                Toggle(L10n.t("รองรับการเลื่อนแนวนอน (ซ้าย-ขวา)", "Enable Horizontal Scroll (Left/Right)", lang: lang), isOn: $config.autoscrollHorizontalEnabled)
                Toggle(L10n.t("กลับทิศทางการเลื่อน (Invert Direction)", "Invert Scroll Direction", lang: lang), isOn: $config.autoscrollInvertDirection)
            }
        }
        .formStyle(.grouped)
    }
}

private struct TrackpadSettingsTab: View {
    @ObservedObject var config: TiffyClickConfig

    private var lang: AppLanguage { config.language }

    var body: some View {
        Form {
            Section(L10n.t("แทร็กแพด และ Magic Mouse", "Trackpad & Magic Mouse", lang: lang)) {
                Stepper(value: $config.minimumFingers, in: 2...10) {
                    HStack {
                        Text(L10n.t("จำนวนนิ้วสำหรับ Middle Click", "Fingers for Middle Click", lang: lang))
                        Spacer()
                        Text(L10n.t("\(config.minimumFingers) นิ้ว", "\(config.minimumFingers) fingers", lang: lang))
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                    }
                }

                HStack(spacing: 8) {
                    Text(L10n.t("เลือกด่วน:", "Quick pick:", lang: lang))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    ForEach([2, 3, 4, 5], id: \.self) { count in
                        Button("\(count)") {
                            config.minimumFingers = count
                        }
                        .buttonStyle(.bordered)
                        .tint(config.minimumFingers == count ? .accentColor : .secondary)
                    }
                }

                Toggle(
                    L10n.t("รองรับนิ้วมากกว่าที่กำหนด (\(config.minimumFingers)+ นิ้ว)", "Allow more than \(config.minimumFingers) fingers (\(config.minimumFingers)+)", lang: lang),
                    isOn: $config.allowMoreFingers
                )
                Toggle(L10n.t("แตะเพื่อคลิกกลาง (Tap to Middle Click)", "Tap to Middle Click", lang: lang), isOn: $config.tapToClick)
            }

            Section(L10n.t("ความไวและกันอุ้งมือ", "Sensitivity & Palm Rejection", lang: lang)) {
                HStack {
                    Text(L10n.t("ระยะเวลาแตะสูงสุด", "Max Tap Duration", lang: lang))
                    Slider(value: $config.maxTapDurationMs, in: 100...600, step: 25)
                    Text("\(Int(config.maxTapDurationMs)) ms")
                        .monospacedDigit()
                        .frame(width: 56, alignment: .trailing)
                }

                HStack {
                    Text(L10n.t("ระยะขยับนิ้วสูงสุดตอนแตะ", "Max Tap Movement", lang: lang))
                    Slider(value: $config.maxTapDistance, in: 0.01...0.15, step: 0.01)
                    Text(String(format: "%.2f", config.maxTapDistance))
                        .monospacedDigit()
                        .frame(width: 42, alignment: .trailing)
                }

                HStack {
                    Text(L10n.t("กันอุ้งมือขอบ Trackpad (Palm Rejection)", "Edge Palm Rejection Margin", lang: lang))
                    Slider(value: $config.palmRejectionMargin, in: 0.0...0.15, step: 0.01)
                    Text("\(Int((config.palmRejectionMargin * 100).rounded()))%")
                        .monospacedDigit()
                        .frame(width: 42, alignment: .trailing)
                }
            }

            if config.minimumFingers == 3 && (SystemPermissions.isThreeFingerDragEnabled() || SystemPermissions.isThreeFingerTapEnabled()) {
                Section(L10n.t("คำเตือน Gesture ชนกับระบบ", "System Gesture Conflict Warning", lang: lang)) {
                    if SystemPermissions.isThreeFingerDragEnabled() {
                        Label(
                            L10n.t(
                                "คุณเปิด Three Finger Drag ไว้ใน macOS แนะนำให้เปลี่ยนเป็น 4 นิ้ว หรือปิด Three Finger Drag",
                                "macOS Three Finger Drag is enabled. Switch to 4 fingers or disable Three Finger Drag in System Settings.",
                                lang: lang
                            ),
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundColor(.orange)
                        .font(.caption)
                    }
                    if SystemPermissions.isThreeFingerTapEnabled() && config.tapToClick {
                        Label(
                            L10n.t(
                                "คุณเปิด Look up (Tap with Three Fingers) ไว้ ซึ่งอาจทำงานพร้อมกันตอนแตะ 3 นิ้ว",
                                "macOS Three Finger Tap (Look up) is enabled and may fire alongside 3-finger tap.",
                                lang: lang
                            ),
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundColor(.orange)
                        .font(.caption)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct AppsSettingsTab: View {
    @ObservedObject var config: TiffyClickConfig
    @State private var newBundleID = ""

    private var lang: AppLanguage { config.language }

    var body: some View {
        Form {
            Section(L10n.t("แอปที่ปิด Autoscroll (ยังใช้ Middle-Click & Middle-Drag ปกติ)", "Disable Autoscroll Only (Keep Middle-Click & Middle-Drag)", lang: lang)) {
                if config.autoscrollIgnoredBundles.isEmpty {
                    Text(L10n.t(
                        "ยังไม่มีแอปที่ยกเว้น (เหมาะสำหรับเพิ่ม Figma, Blender, CAD)",
                        "No excluded apps yet (great for Figma, Blender, CAD).",
                        lang: lang
                    ))
                    .font(.caption)
                    .foregroundColor(.secondary)
                } else {
                    ForEach(Array(config.autoscrollIgnoredBundles).sorted(), id: \.self) { bundleID in
                        HStack {
                            Text(bundleID)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button(role: .destructive) {
                                config.autoscrollIgnoredBundles.remove(bundleID)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                HStack {
                    TextField(
                        L10n.t("เช่น com.figma.Desktop หรือ org.blenderfoundation.blender", "e.g. com.figma.Desktop or org.blenderfoundation.blender", lang: lang),
                        text: $newBundleID
                    )
                    Button(L10n.t("เพิ่ม", "Add", lang: lang)) {
                        let trimmed = newBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        config.autoscrollIgnoredBundles.insert(trimmed)
                        newBundleID = ""
                    }
                    .disabled(newBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section(L10n.t("แอปที่ปิด tiffy-click ทั้งหมด (Ignored Apps)", "Completely Ignored Apps", lang: lang)) {
                if config.ignoredAppBundles.isEmpty {
                    Text(L10n.t(
                        "ยังไม่มีแอปที่ถูกยกเว้น — สามารถกด 'ยกเว้นแอปนี้' จาก Menu Bar ได้ทันที",
                        "No ignored apps yet — toggle directly from the Menu Bar while focused on any app.",
                        lang: lang
                    ))
                    .font(.caption)
                    .foregroundColor(.secondary)
                } else {
                    ForEach(Array(config.ignoredAppBundles).sorted(), id: \.self) { bundleID in
                        HStack {
                            Text(bundleID)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button(role: .destructive) {
                                config.ignoredAppBundles.remove(bundleID)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutSettingsTab: View {
    @ObservedObject var updater: UpdateChecker
    @ObservedObject var config: TiffyClickConfig
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var lang: AppLanguage { config.language }

    var body: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 6)

            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 72, height: 72)
            } else {
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(.linearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
            }

            VStack(spacing: 4) {
                Text("tiffy-click")
                    .font(.title2.bold())
                Text("Version \(updater.currentVersion)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(L10n.t(
                    "คลิกกลาง Middle-Drag และ Hold Scroll (Autoscroll) แบบ Windows สำหรับ macOS",
                    "Universal Middle-Click, Middle-Drag & Windows-Style Autoscroll for macOS",
                    lang: lang
                ))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            }

            Picker(L10n.t("ภาษา / Language", "Language / ภาษา", lang: lang), selection: $config.language) {
                ForEach(AppLanguage.allCases) { item in
                    Text(item.displayName).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)

            Toggle(L10n.t("เปิดอัตโนมัติเมื่อเข้าสู่ระบบ (Launch at Login)", "Launch at Login", lang: lang), isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        logger.error("Failed to toggle Launch at Login: \(error.localizedDescription)")
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
                .padding(.horizontal, 40)

            HStack(spacing: 12) {
                Button(L10n.t("ตรวจสอบอัปเดต", "Check for Updates", lang: lang)) {
                    updater.checkForUpdates(silent: false)
                }
                .disabled(updater.isChecking)

                Button(L10n.t("รีเซ็ตค่าเริ่มต้น", "Reset Defaults", lang: lang)) {
                    config.resetDefaults()
                }
            }

            if !updater.statusMessage.isEmpty {
                Text(updater.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("Inspired by artginzburg/MiddleClick • GPL-3.0")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.bottom, 6)
        }
        .padding()
    }
}
