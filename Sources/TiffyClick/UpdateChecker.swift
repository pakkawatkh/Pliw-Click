import AppKit
import Foundation
import TiffyClickCore

struct ReleaseMetadata: Decodable {
    let latestVersion: String
    let downloadUrl: String
    let zipUrl: String?
    let releaseNotes: String?
    let publishedAt: String?
}

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var isChecking = false
    @Published var statusMessage: String = ""
    @Published var availableRelease: ReleaseMetadata?

    static let versionURL = URL(string: "https://pakkawatkh.github.io/tiffy-app/tiffy-click/version.json")!

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var lang: AppLanguage { TiffyClickConfig.shared.language }

    func checkForUpdates(silent: Bool = false) {
        guard !isChecking else { return }
        isChecking = true
        if !silent {
            statusMessage = L10n.t("กำลังตรวจสอบอัปเดต...", "Checking for updates...", lang: lang)
        }

        Task {
            defer { isChecking = false }
            do {
                var request = URLRequest(url: Self.versionURL)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.timeoutInterval = 10

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    if !silent {
                        statusMessage = L10n.t("ไม่สามารถตรวจสอบอัปเดตได้ในขณะนี้", "Unable to check for updates right now.", lang: lang)
                    }
                    return
                }

                let meta = try JSONDecoder().decode(ReleaseMetadata.self, from: data)
                if VersionComparator.isNewer(meta.latestVersion, than: currentVersion) {
                    availableRelease = meta
                    statusMessage = L10n.t(
                        "มีเวอร์ชันใหม่ v\(meta.latestVersion) พร้อมให้อัปเดต",
                        "New version v\(meta.latestVersion) is available",
                        lang: lang
                    )
                    if !silent {
                        presentUpdateAlert(meta)
                    }
                } else {
                    availableRelease = nil
                    statusMessage = L10n.t(
                        "คุณใช้เวอร์ชันล่าสุดแล้ว (v\(currentVersion))",
                        "You're up to date (v\(currentVersion))",
                        lang: lang
                    )
                    if !silent {
                        let alert = NSAlert()
                        alert.messageText = L10n.t("tiffy-click เป็นเวอร์ชันล่าสุดแล้ว", "tiffy-click is up to date", lang: lang)
                        alert.informativeText = L10n.t("เวอร์ชันปัจจุบัน: v\(currentVersion)", "Current version: v\(currentVersion)", lang: lang)
                        alert.runModal()
                    }
                }
            } catch {
                if !silent {
                    statusMessage = L10n.t(
                        "ตรวจสอบอัปเดตไม่สำเร็จ: \(error.localizedDescription)",
                        "Update check failed: \(error.localizedDescription)",
                        lang: lang
                    )
                }
            }
        }
    }

    func presentUpdateAlert(_ meta: ReleaseMetadata) {
        let alert = NSAlert()
        alert.messageText = L10n.t(
            "พบเวอร์ชันใหม่ของ tiffy-click (v\(meta.latestVersion))",
            "New version of tiffy-click available (v\(meta.latestVersion))",
            lang: lang
        )
        alert.informativeText = """
        \(L10n.t("เวอร์ชันปัจจุบัน", "Current version", lang: lang)): v\(currentVersion)

        \(meta.releaseNotes ?? "")
        """
        alert.addButton(withTitle: L10n.t("ดาวน์โหลดอัปเดต", "Download Update", lang: lang))
        alert.addButton(withTitle: L10n.t("ภายหลัง", "Later", lang: lang))

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: meta.downloadUrl) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
