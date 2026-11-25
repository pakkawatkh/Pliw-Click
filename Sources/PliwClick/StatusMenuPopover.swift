import AppKit
import SwiftUI
import PliwClickCore

struct FrontmostAppSnapshot: Equatable {
    let name: String
    let bundleID: String
    let isBrowser: Bool
}

enum PopoverExpandableSection: Equatable {
    case fingers
    case currentApp
    case language
}

@MainActor
final class StatusPopoverViewModel: ObservableObject {
    @Published var frontmostApp: FrontmostAppSnapshot?
    @Published var isOptionPressed: Bool = false
    @Published var expandedSection: PopoverExpandableSection? = nil

    func refreshFrontmostApp() {
        let ownBundleID = Bundle.main.bundleIdentifier
        if let app = AppInspector.frontmostApp(),
           let name = app.localizedName,
           let bundleID = app.bundleIdentifier,
           bundleID != ownBundleID {
            frontmostApp = FrontmostAppSnapshot(
                name: name,
                bundleID: bundleID,
                isBrowser: BrowserRegistry.isBrowser(bundleID: bundleID)
            )
        } else {
            frontmostApp = nil
        }
    }

    func toggleSection(_ section: PopoverExpandableSection) {
        withAnimation(.easeInOut(duration: 0.14)) {
            if expandedSection == section {
                expandedSection = nil
            } else {
                expandedSection = section
            }
        }
    }
}

struct StatusPopoverView: View {
    @ObservedObject var config: PliwClickConfig
    @ObservedObject var accessibilityMonitor: AccessibilityMonitor
    @ObservedObject var viewModel: StatusPopoverViewModel

    let currentVersion: String
    let onOpenAccessibility: () -> Void
    let onRestartListeners: () -> Void
    let onOpenSettings: () -> Void
    let onCheckUpdates: () -> Void
    let onQuit: () -> Void

    private var lang: AppLanguage { config.language }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !accessibilityMonitor.isTrusted {
                accessibilitySection
                menuDivider
            }

            // Section 1: Core toggles (stays open on click)
            CheckmarkMenuRow(
                title: L10n.t("เปิดใช้งาน", "Enabled", lang: lang),
                isChecked: config.isEnabled
            ) {
                config.isEnabled.toggle()
            }

            CheckmarkMenuRow(
                title: L10n.t("เลื่อนอัตโนมัติ (Autoscroll)", "Autoscroll", lang: lang),
                isChecked: config.autoscrollEnabled
            ) {
                config.autoscrollEnabled.toggle()
            }

            CheckmarkMenuRow(
                title: L10n.t("แตะเพื่อคลิกกลาง", "Tap to Click", lang: lang),
                isChecked: config.tapToClick
            ) {
                config.tapToClick.toggle()
            }

            menuDivider

            // Section 2: Expandable inline submenus (stays open on click)
            fingersSection

            if let app = viewModel.frontmostApp {
                currentAppSection(app)
            }

            menuDivider

            // Section 3: App controls
            if viewModel.isOptionPressed {
                IconMenuRow(
                    symbol: "arrow.clockwise",
                    title: L10n.t("รีสตาร์ทตัวจับนิ้ว", "Restart Listeners", lang: lang),
                    shortcut: "⌥⌘,"
                ) {
                    onRestartListeners()
                }
            } else {
                IconMenuRow(
                    symbol: "gearshape",
                    title: L10n.t("การตั้งค่า…", "Settings…", lang: lang),
                    shortcut: "⌘,"
                ) {
                    onOpenSettings()
                }
            }

            languageSection

            menuDivider

            // Section 4: Updates & Quit
            PlainMenuRow(
                title: L10n.t(
                    "v\(currentVersion) · ตรวจหาอัปเดต…",
                    "v\(currentVersion) · Check for Updates…",
                    lang: lang
                )
            ) {
                onCheckUpdates()
            }

            PlainMenuRow(
                title: L10n.t("ออกจาก Pliw Click", "Quit Pliw Click", lang: lang),
                shortcut: "⌘Q"
            ) {
                onQuit()
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .frame(width: 264)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Sections

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                    .frame(width: 16, alignment: .center)
                Text(L10n.t("ต้องการสิทธิ์การช่วยการเข้าถึง", "Accessibility Required", lang: lang))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)

            IconMenuRow(
                symbol: "lock.shield",
                title: L10n.t("เปิดการตั้งค่าความเป็นส่วนตัว…", "Open Privacy Settings…", lang: lang)
            ) {
                onOpenAccessibility()
            }
        }
    }

    private var fingersSection: some View {
        let plus = config.allowMoreFingers ? "+" : ""
        let title = L10n.t(
            "จำนวนนิ้ว (\(config.minimumFingers)\(plus))",
            "Fingers (\(config.minimumFingers)\(plus))",
            lang: lang
        )
        let isExpanded = viewModel.expandedSection == .fingers

        return VStack(alignment: .leading, spacing: 2) {
            ExpandableMenuRow(
                symbol: "hand.tap",
                title: title,
                isExpanded: isExpanded
            ) {
                viewModel.toggleSection(.fingers)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 5)
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(2...10, id: \.self) { count in
                            FingerCountPill(
                                count: count,
                                isSelected: config.minimumFingers == count
                            ) {
                                config.minimumFingers = count
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 4)

                    CheckmarkMenuRow(
                        title: L10n.t(
                            "รองรับ \(config.minimumFingers) นิ้วขึ้นไป",
                            "Allow \(config.minimumFingers)+ Fingers",
                            lang: lang
                        ),
                        isChecked: config.allowMoreFingers,
                        compact: true
                    ) {
                        config.allowMoreFingers.toggle()
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            }
        }
    }

    private func currentAppSection(_ app: FrontmostAppSnapshot) -> some View {
        let isExpanded = viewModel.expandedSection == .currentApp
        let isAutoscrollIgnored = app.isBrowser && config.autoscrollIgnoredBundles.contains(app.bundleID)
        let isAppIgnored = config.ignoredAppBundles.contains(app.bundleID)

        return VStack(alignment: .leading, spacing: 2) {
            ExpandableMenuRow(
                symbol: "macwindow",
                title: app.name,
                isExpanded: isExpanded
            ) {
                viewModel.toggleSection(.currentApp)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    CheckmarkMenuRow(
                        title: L10n.t("ปิด Autoscroll ในแอปนี้", "Pause Autoscroll", lang: lang),
                        isChecked: isAutoscrollIgnored,
                        isEnabled: app.isBrowser,
                        compact: true
                    ) {
                        config.toggleAutoscrollIgnoredApp(app.bundleID)
                    }

                    CheckmarkMenuRow(
                        title: L10n.t("ยกเว้นแอปนี้ทั้งหมด", "Ignore App", lang: lang),
                        isChecked: isAppIgnored,
                        compact: true
                    ) {
                        config.toggleIgnoredApp(app.bundleID)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            }
        }
    }

    private var languageSection: some View {
        let isExpanded = viewModel.expandedSection == .language

        return VStack(alignment: .leading, spacing: 2) {
            ExpandableMenuRow(
                symbol: "globe",
                title: L10n.t("ภาษา", "Language", lang: lang),
                trailingText: lang == .th ? "ไทย" : "EN",
                isExpanded: isExpanded
            ) {
                viewModel.toggleSection(.language)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    CheckmarkMenuRow(
                        title: "ไทย",
                        isChecked: lang == .th,
                        compact: true
                    ) {
                        config.language = .th
                    }

                    CheckmarkMenuRow(
                        title: "English",
                        isChecked: lang == .en,
                        compact: true
                    ) {
                        config.language = .en
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            }
        }
    }

    private var menuDivider: some View {
        Divider()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
    }
}

// MARK: - Reusable Native-Style Menu Rows

private struct CheckmarkMenuRow: View {
    let title: String
    let isChecked: Bool
    var isEnabled: Bool = true
    var compact: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: compact ? 11 : 12, weight: .semibold))
                    .opacity(isChecked ? 1 : 0)
                    .frame(width: 16, alignment: .center)

                Text(title)
                    .font(.system(size: compact ? 12.5 : 13))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, compact ? 4 : 5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered && isEnabled ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var foregroundColor: Color {
        if !isEnabled {
            return .secondary.opacity(0.5)
        }
        return isHovered ? .white : .primary
    }
}

private struct IconMenuRow: View {
    let symbol: String
    let title: String
    var shortcut: String? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13))
                    .frame(width: 16, alignment: .center)

                Text(title)
                    .font(.system(size: 13))
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 12))
                        .foregroundStyle(isHovered ? Color.white.opacity(0.85) : Color.secondary)
                }
            }
            .foregroundStyle(isHovered ? .white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct ExpandableMenuRow: View {
    let symbol: String
    let title: String
    var trailingText: String? = nil
    let isExpanded: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13))
                    .frame(width: 16, alignment: .center)

                Text(title)
                    .font(.system(size: 13))
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let trailingText {
                    Text(trailingText)
                        .font(.system(size: 11.5))
                        .foregroundStyle(isHovered ? Color.white.opacity(0.85) : Color.secondary)
                }

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(isHovered ? Color.white.opacity(0.9) : Color.secondary)
                    .frame(width: 12, alignment: .center)
            }
            .foregroundStyle(isHovered ? .white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct PlainMenuRow: View {
    let title: String
    var shortcut: String? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Color.clear
                    .frame(width: 16, height: 1)

                Text(title)
                    .font(.system(size: 13))
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 12))
                        .foregroundStyle(isHovered ? Color.white.opacity(0.85) : Color.secondary)
                }
            }
            .foregroundStyle(isHovered ? .white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct FingerCountPill: View {
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text("\(count)")
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(backgroundColor)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor
        }
        if isHovered {
            return Color.primary.opacity(0.12)
        }
        return Color.primary.opacity(0.06)
    }
}
