import AppKit
import Foundation
import SwiftUI
import TiffyClickCore

struct ReleaseMetadata: Decodable {
    let latestVersion: String
    let downloadUrl: String
    let zipUrl: String?
    let releaseNotes: String?
    let publishedAt: String?
}

// MARK: - macOS Liquid Glass Update Toast

private enum UpdateToastState {
    case upToDate(version: String)
    case updateAvailable(meta: ReleaseMetadata, currentVersion: String)
    case downloading(version: String)
    case error(message: String)
}

@MainActor
private final class UpdateToastModel: ObservableObject {
    @Published var state: UpdateToastState = .upToDate(version: "1.0.0")
    @Published var isVisible: Bool = false
    @Published var language: AppLanguage = TiffyClickConfig.shared.language
    var onUpdate: (() -> Void)?
    var onDismiss: (() -> Void)?
}

private struct ToastGlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 16
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.state = .active
    }
}

private struct UpdateToastView: View {
    @ObservedObject var model: UpdateToastModel
    @Environment(\.colorScheme) private var colorScheme

    private var lang: AppLanguage { model.language }

    var body: some View {
        HStack(spacing: 12) {
            // App icon badge
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 34, height: 34)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                switch model.state {
                case let .upToDate(version):
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 12, weight: .semibold))
                        Text(L10n.t("เป็นเวอร์ชันล่าสุดแล้ว", "Up to Date", lang: lang))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text("Tiffy Click v\(version)")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)

                case let .updateAvailable(meta, currentVersion):
                    Text(L10n.t("มีอัปเดตใหม่ v\(meta.latestVersion)", "Update Available · v\(meta.latestVersion)", lang: lang))
                        .font(.system(size: 13, weight: .semibold))
                    Text(L10n.t("ปัจจุบัน v\(currentVersion)", "Current v\(currentVersion)", lang: lang))
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)

                case let .downloading(version):
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text(L10n.t("กำลังอัปเดตเป็น v\(version)…", "Updating to v\(version)…", lang: lang))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text(L10n.t("แอปจะเปิดใหม่ให้อัตโนมัติ", "The app will relaunch automatically", lang: lang))
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)

                case let .error(message):
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 12, weight: .semibold))
                        Text(L10n.t("ตรวจหาอัปเดตไม่สำเร็จ", "Update Check Failed", lang: lang))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text(message)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            // Action buttons (only shown when update is available)
            if case .updateAvailable = model.state {
                Button(L10n.t("อัปเดต", "Update", lang: lang)) {
                    model.onUpdate?()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    model.onDismiss?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(width: 320, alignment: .leading)
        .background(
            ZStack {
                ToastGlassBackground()
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black.opacity(0.18) : Color.white.opacity(0.28))
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.38 : 0.85),
                                Color.white.opacity(colorScheme == .dark ? 0.10 : 0.25)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.9
                    )
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(colorScheme == .dark ? 0.40 : 0.12), lineWidth: 0.5)
            }
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.18), radius: 14, x: 0, y: 6)
        .padding(14)
        .offset(y: model.isVisible ? 0 : -12)
        .scaleEffect(model.isVisible ? 1.0 : 0.94)
        .opacity(model.isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: model.isVisible)
    }
}

@MainActor
private final class UpdateToastController {
    private let model = UpdateToastModel()
    private var panel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?

    func show(
        state: UpdateToastState,
        autoHideAfter delay: TimeInterval?,
        onUpdate: (() -> Void)? = nil
    ) {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil

        model.language = TiffyClickConfig.shared.language
        model.state = state
        model.onUpdate = onUpdate
        model.onDismiss = { [weak self] in
            self?.hide()
        }

        let panel = ensurePanel()
        positionTopRight(panel)
        panel.orderFrontRegardless()

        DispatchQueue.main.async { [weak self] in
            self?.model.isVisible = true
        }

        if let delay {
            let item = DispatchWorkItem { [weak self] in
                self?.hide()
            }
            dismissWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }

    func hide() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        model.isVisible = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak self] in
            guard let self, !self.model.isVisible else { return }
            self.panel?.orderOut(nil)
        }
    }

    private func positionTopRight(_ panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = visible.maxX - size.width - 4
        let y = visible.maxY - size.height - 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func ensurePanel() -> NSPanel {
        if let existing = panel { return existing }

        let width: CGFloat = 348
        let height: CGFloat = 92
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let hosting = NSHostingView(rootView: UpdateToastView(model: model))
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
        p.contentView = hosting

        self.panel = p
        return p
    }
}

// MARK: - UpdateChecker

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var isChecking = false
    @Published var statusMessage: String = ""
    @Published var availableRelease: ReleaseMetadata?

    static let versionURL = URL(string: "https://pakkawatkh.github.io/tiffy-app/tiffy-click/version.json")!

    private let toast = UpdateToastController()

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var lang: AppLanguage { TiffyClickConfig.shared.language }

    func checkForUpdates(silent: Bool = false) {
        guard !isChecking else { return }
        isChecking = true
        if !silent {
            statusMessage = L10n.t("กำลังตรวจสอบอัปเดต…", "Checking for updates…", lang: lang)
        }

        Task {
            defer { isChecking = false }
            do {
                var request = URLRequest(url: Self.versionURL)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.timeoutInterval = 10

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    let msg = L10n.t("ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้", "Unable to reach update server", lang: lang)
                    if !silent {
                        statusMessage = msg
                        toast.show(state: .error(message: msg), autoHideAfter: 3.0)
                    }
                    return
                }

                let meta = try JSONDecoder().decode(ReleaseMetadata.self, from: data)
                if VersionComparator.isNewer(meta.latestVersion, than: currentVersion) {
                    availableRelease = meta
                    statusMessage = L10n.t(
                        "มีเวอร์ชันใหม่ v\(meta.latestVersion)",
                        "Update available (v\(meta.latestVersion))",
                        lang: lang
                    )
                    toast.show(
                        state: .updateAvailable(meta: meta, currentVersion: currentVersion),
                        autoHideAfter: 12.0,
                        onUpdate: { [weak self] in
                            self?.performUpdate(meta)
                        }
                    )
                } else {
                    availableRelease = nil
                    statusMessage = L10n.t(
                        "เป็นเวอร์ชันล่าสุดแล้ว (v\(currentVersion))",
                        "Up to date (v\(currentVersion))",
                        lang: lang
                    )
                    if !silent {
                        toast.show(
                            state: .upToDate(version: currentVersion),
                            autoHideAfter: 2.8
                        )
                    }
                }
            } catch {
                if !silent {
                    statusMessage = error.localizedDescription
                    toast.show(state: .error(message: error.localizedDescription), autoHideAfter: 3.0)
                }
            }
        }
    }

    func performUpdate(_ meta: ReleaseMetadata) {
        guard let zipStr = meta.zipUrl, let zipURL = URL(string: zipStr) else {
            openDownloadPage(meta)
            return
        }

        toast.show(state: .downloading(version: meta.latestVersion), autoHideAfter: nil)

        Task {
            do {
                let (downloadedURL, response) = try await URLSession.shared.download(from: zipURL)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    openDownloadPage(meta)
                    toast.hide()
                    return
                }

                let fm = FileManager.default
                let tempDir = fm.temporaryDirectory.appendingPathComponent("tiffy-click-update-\(UUID().uuidString)")
                try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

                let ditto = Process()
                ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                ditto.arguments = ["-xk", downloadedURL.path, tempDir.path]
                try ditto.run()
                ditto.waitUntilExit()

                let candidateNew = tempDir.appendingPathComponent("Tiffy Click.app")
                let candidateOld = tempDir.appendingPathComponent("tiffy-click.app")
                let extractedApp = fm.fileExists(atPath: candidateNew.path) ? candidateNew : candidateOld
                guard ditto.terminationStatus == 0, fm.fileExists(atPath: extractedApp.path) else {
                    openDownloadPage(meta)
                    toast.hide()
                    return
                }

                let targetApp = URL(fileURLWithPath: "/Applications/Tiffy Click.app")
                let legacyApp = URL(fileURLWithPath: "/Applications/tiffy-click.app")
                if fm.fileExists(atPath: targetApp.path) {
                    try fm.removeItem(at: targetApp)
                }
                if fm.fileExists(atPath: legacyApp.path) {
                    try? fm.removeItem(at: legacyApp)
                }
                try fm.copyItem(at: extractedApp, to: targetApp)
                try? fm.removeItem(at: tempDir)

                // Relaunch newly installed version cleanly
                let relaunch = Process()
                relaunch.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                relaunch.arguments = ["-n", targetApp.path]
                try relaunch.run()

                NSApp.terminate(nil)
            } catch {
                logger.error("In-app update failed: \(error.localizedDescription)")
                openDownloadPage(meta)
                toast.hide()
            }
        }
    }

    private func openDownloadPage(_ meta: ReleaseMetadata) {
        if let url = URL(string: meta.downloadUrl) {
            NSWorkspace.shared.open(url)
        }
    }
}
