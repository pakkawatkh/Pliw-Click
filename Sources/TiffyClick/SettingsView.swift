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
            GeneralSettingsTab(config: config, accessibilityMonitor: accessibilityMonitor)
                .tabItem {
                    Label(L10n.t("ทั่วไป", "General", lang: lang), systemImage: "slider.horizontal.3")
                }

            TrackpadSettingsTab(config: config)
                .tabItem {
                    Label(L10n.t("แทร็กแพด", "Trackpad", lang: lang), systemImage: "hand.tap")
                }

            AppsSettingsTab(config: config)
                .tabItem {
                    Label(L10n.t("แอป", "Apps", lang: lang), systemImage: "macwindow")
                }

            AboutSettingsTab(updater: updater, config: config)
                .tabItem {
                    Label(L10n.t("เกี่ยวกับ", "About", lang: lang), systemImage: "info.circle")
                }
        }
        .frame(width: 490, height: 420)
    }
}

private struct GeneralSettingsTab: View {
    @ObservedObject var config: TiffyClickConfig
    @ObservedObject var accessibilityMonitor: AccessibilityMonitor
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var lang: AppLanguage { config.language }

    var body: some View {
        Form {
            if !accessibilityMonitor.isTrusted {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("ต้องการสิทธิ์การช่วยการเข้าถึง", "Accessibility Required", lang: lang))
                                .font(.headline)
                            Text(L10n.t(
                                "อนุญาตใน การตั้งค่าระบบ เพื่อเปิดใช้งานคลิกกลางและ Autoscroll",
                                "Allow Tiffy Click in System Settings to enable middle-click and Autoscroll.",
                                lang: lang
                            ))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(L10n.t("เปิดตั้งค่า", "Open", lang: lang)) {
                            SystemPermissions.openAccessibilitySettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section(L10n.t("ทั่วไป", "General", lang: lang)) {
                Toggle(L10n.t("เปิดใช้งาน Tiffy Click", "Enable Tiffy Click", lang: lang), isOn: $config.isEnabled)

                Toggle(L10n.t("เปิดอัตโนมัติเมื่อเข้าสู่ระบบ", "Launch at Login", lang: lang), isOn: $launchAtLogin)
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

                Picker(L10n.t("ภาษา", "Language", lang: lang), selection: $config.language) {
                    Text("ไทย").tag(AppLanguage.th)
                    Text("English").tag(AppLanguage.en)
                }
                .pickerStyle(.segmented)
            }

            Section(L10n.t("เลื่อนอัตโนมัติในเบราว์เซอร์ (Autoscroll)", "Browser Autoscroll", lang: lang)) {
                Toggle(L10n.t("เปิดใช้งาน Autoscroll", "Enable Autoscroll", lang: lang), isOn: $config.autoscrollEnabled)

                Toggle(L10n.t("รองรับปุ่มกลางของเมาส์ภายนอก", "Physical Mouse Middle Button", lang: lang), isOn: $config.autoscrollForPhysicalMouse)

                HStack {
                    Text(L10n.t("ความเร็ว", "Speed", lang: lang))
                    Slider(value: $config.autoscrollSpeed, in: 0.3...3.0, step: 0.1)
                    Text(String(format: "%.1fx", config.autoscrollSpeed))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }

                HStack {
                    Text(L10n.t("ระยะหยุดตรงกลาง", "Deadzone", lang: lang))
                    Slider(value: $config.autoscrollDeadzone, in: 4...36, step: 1)
                    Text("\(Int(config.autoscrollDeadzone)) px")
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                        .frame(width: 42, alignment: .trailing)
                }

                Toggle(L10n.t("เลื่อนแนวนอน", "Horizontal Scroll", lang: lang), isOn: $config.autoscrollHorizontalEnabled)
                Toggle(L10n.t("กลับทิศทางการเลื่อน", "Invert Direction", lang: lang), isOn: $config.autoscrollInvertDirection)
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
                        Text(L10n.t("จำนวนนิ้ว", "Fingers", lang: lang))
                        Spacer()
                        Text(L10n.t("\(config.minimumFingers) นิ้ว", "\(config.minimumFingers)", lang: lang))
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)
                    }
                }

                HStack(spacing: 6) {
                    Text(L10n.t("เลือกด่วน", "Quick Pick", lang: lang))
                        .foregroundColor(.secondary)
                    Spacer()
                    ForEach([2, 3, 4, 5], id: \.self) { count in
                        Button("\(count)") {
                            config.minimumFingers = count
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(config.minimumFingers == count ? .accentColor : .secondary)
                    }
                }

                Toggle(
                    L10n.t("รองรับ \(config.minimumFingers) นิ้วขึ้นไป", "Allow \(config.minimumFingers)+ Fingers", lang: lang),
                    isOn: $config.allowMoreFingers
                )
                Toggle(L10n.t("แตะเพื่อคลิกกลาง", "Tap to Click", lang: lang), isOn: $config.tapToClick)
            }

            Section(L10n.t("ความแม่นยำ", "Precision", lang: lang)) {
                HStack {
                    Text(L10n.t("เวลาแตะสูงสุด", "Tap Duration", lang: lang))
                    Slider(value: $config.maxTapDurationMs, in: 100...600, step: 25)
                    Text("\(Int(config.maxTapDurationMs)) ms")
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }

                HStack {
                    Text(L10n.t("ระยะขยับตอนแตะ", "Tap Movement", lang: lang))
                    Slider(value: $config.maxTapDistance, in: 0.01...0.15, step: 0.01)
                    Text(String(format: "%.2f", config.maxTapDistance))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }

                HStack {
                    Text(L10n.t("กันอุ้งมือขอบแทร็กแพด", "Edge Palm Rejection", lang: lang))
                    Slider(value: $config.palmRejectionMargin, in: 0.0...0.15, step: 0.01)
                    Text("\(Int((config.palmRejectionMargin * 100).rounded()))%")
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }

            if config.minimumFingers == 3 && (SystemPermissions.isThreeFingerDragEnabled() || SystemPermissions.isThreeFingerTapEnabled()) {
                Section(L10n.t("แจ้งเตือน", "Notice", lang: lang)) {
                    if SystemPermissions.isThreeFingerDragEnabled() {
                        Label(
                            L10n.t(
                                "macOS เปิด Three Finger Drag อยู่ แนะนำให้ใช้ 4 นิ้ว",
                                "macOS Three Finger Drag is active. Consider using 4 fingers.",
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
                                "macOS เปิดแตะ 3 นิ้วเพื่อค้นหาอยู่ อาจทำงานพร้อมกัน",
                                "macOS Three-Finger Tap (Look up) is enabled and may conflict.",
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
            Section(L10n.t("ปิดเฉพาะ Autoscroll", "Pause Autoscroll", lang: lang)) {
                if config.autoscrollIgnoredBundles.isEmpty {
                    Text(L10n.t("ยังไม่มีรายการ", "None", lang: lang))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(config.autoscrollIgnoredBundles).sorted(), id: \.self) { bundleID in
                        HStack {
                            Text(bundleID)
                                .font(.system(.callout, design: .monospaced))
                            Spacer()
                            Button(role: .destructive) {
                                config.autoscrollIgnoredBundles.remove(bundleID)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                HStack {
                    TextField("com.google.Chrome", text: $newBundleID)
                    Button(L10n.t("เพิ่ม", "Add", lang: lang)) {
                        let trimmed = newBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        config.autoscrollIgnoredBundles.insert(trimmed)
                        newBundleID = ""
                    }
                    .controlSize(.small)
                    .disabled(newBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section(L10n.t("ยกเว้นแอปทั้งหมด", "Ignored Apps", lang: lang)) {
                if config.ignoredAppBundles.isEmpty {
                    Text(L10n.t("ยังไม่มีรายการ", "None", lang: lang))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(config.ignoredAppBundles).sorted(), id: \.self) { bundleID in
                        HStack {
                            Text(bundleID)
                                .font(.system(.callout, design: .monospaced))
                            Spacer()
                            Button(role: .destructive) {
                                config.ignoredAppBundles.remove(bundleID)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.secondary)
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

    private var lang: AppLanguage { config.language }

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 76, height: 76)
            }

            VStack(spacing: 4) {
                Text("Tiffy Click")
                    .font(.title2.weight(.semibold))
                Text(L10n.t("เวอร์ชัน \(updater.currentVersion)", "Version \(updater.currentVersion)", lang: lang))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(L10n.t(
                    "คลิกกลาง Middle-Drag และ Autoscroll สำหรับ macOS",
                    "Middle-Click, Middle-Drag & Autoscroll for macOS",
                    lang: lang
                ))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
            }

            HStack(spacing: 10) {
                Button(L10n.t("ตรวจหาอัปเดต", "Check for Updates", lang: lang)) {
                    updater.checkForUpdates(silent: false)
                }
                .disabled(updater.isChecking)

                Button(L10n.t("รีเซ็ตค่าเริ่มต้น", "Reset Defaults", lang: lang)) {
                    config.resetDefaults()
                }
            }
            .padding(.top, 4)

            if !updater.statusMessage.isEmpty {
                Text(updater.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("© 2026 Pakkawat.k • Open Source (MIT)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 8)
        }
        .padding()
    }
}
