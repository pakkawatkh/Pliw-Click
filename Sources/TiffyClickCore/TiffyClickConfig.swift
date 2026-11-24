import Foundation
import CoreFoundation

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case th
    case en

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .th: return "ไทย (Thai)"
        case .en: return "English"
        }
    }

    public static var systemDefault: AppLanguage {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return preferred.hasPrefix("th") ? .th : .en
    }
}

public enum BrowserRegistry {
    private static let exactBundleIDs: Set<String> = [
        "com.google.chrome",
        "com.google.chrome.canary",
        "com.google.chrome.beta",
        "com.google.chrome.dev",
        "com.apple.safari",
        "com.apple.safaritechnologypreview",
        "company.thebrowser.browser",
        "company.thebrowser.dia",
        "com.brave.browser",
        "com.brave.browser.beta",
        "com.brave.browser.nightly",
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.beta",
        "com.microsoft.edgemac.dev",
        "com.microsoft.edgemac.canary",
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "org.mozilla.nightly",
        "app.zen-browser.zen",
        "com.operasoftware.opera",
        "com.operasoftware.operagx",
        "com.vivaldi.vivaldi",
        "com.kagi.kagimacos",
        "org.chromium.chromium",
        "com.sigmaos.sigmaos.macos"
    ]

    public static func isBrowser(bundleID: String?) -> Bool {
        guard let id = bundleID?.lowercased(), !id.isEmpty else { return false }
        return exactBundleIDs.contains(id)
    }
}

/// Immutable thread-safe snapshot read from high-frequency CGEventTap & Multitouch callbacks.
public struct ConfigSnapshot: Sendable, Equatable {
    public var isEnabled: Bool
    public var minimumFingers: Int
    public var allowMoreFingers: Bool
    public var tapToClick: Bool
    public var maxTapDurationSec: TimeInterval
    public var maxTapDistance: Float
    public var palmRejectionMargin: Float
    public var autoscrollEnabled: Bool
    public var autoscrollBrowsersOnly: Bool
    public var autoscrollForPhysicalMouse: Bool
    public var autoscrollSpeed: Double
    public var autoscrollDeadzone: Double
    public var autoscrollDragThreshold: Double
    public var autoscrollHorizontalEnabled: Bool
    public var autoscrollInvertDirection: Bool
    public var ignoredAppBundles: Set<String>
    public var autoscrollIgnoredBundles: Set<String>

    public init(
        isEnabled: Bool = true,
        minimumFingers: Int = 3,
        allowMoreFingers: Bool = false,
        tapToClick: Bool = true,
        maxTapDurationSec: TimeInterval = 0.30,
        maxTapDistance: Float = 0.05,
        palmRejectionMargin: Float = 0.04,
        autoscrollEnabled: Bool = true,
        autoscrollBrowsersOnly: Bool = true,
        autoscrollForPhysicalMouse: Bool = true,
        autoscrollSpeed: Double = 1.0,
        autoscrollDeadzone: Double = 14.0,
        autoscrollDragThreshold: Double = 8.0,
        autoscrollHorizontalEnabled: Bool = true,
        autoscrollInvertDirection: Bool = false,
        ignoredAppBundles: Set<String> = [],
        autoscrollIgnoredBundles: Set<String> = []
    ) {
        self.isEnabled = isEnabled
        self.minimumFingers = minimumFingers
        self.allowMoreFingers = allowMoreFingers
        self.tapToClick = tapToClick
        self.maxTapDurationSec = maxTapDurationSec
        self.maxTapDistance = maxTapDistance
        self.palmRejectionMargin = palmRejectionMargin
        self.autoscrollEnabled = autoscrollEnabled
        self.autoscrollBrowsersOnly = autoscrollBrowsersOnly
        self.autoscrollForPhysicalMouse = autoscrollForPhysicalMouse
        self.autoscrollSpeed = autoscrollSpeed
        self.autoscrollDeadzone = autoscrollDeadzone
        self.autoscrollDragThreshold = autoscrollDragThreshold
        self.autoscrollHorizontalEnabled = autoscrollHorizontalEnabled
        self.autoscrollInvertDirection = autoscrollInvertDirection
        self.ignoredAppBundles = ignoredAppBundles
        self.autoscrollIgnoredBundles = autoscrollIgnoredBundles
    }
}

public final class TiffyClickConfig: ObservableObject {
    public static let shared = TiffyClickConfig()

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var _snapshot: ConfigSnapshot

    private enum Keys {
        static let language = "appLanguage"
        static let isEnabled = "isEnabled"
        static let minimumFingers = "minimumFingers"
        static let allowMoreFingers = "allowMoreFingers"
        static let tapToClick = "tapToClick"
        static let maxTapDurationMs = "maxTapDurationMs"
        static let maxTapDistance = "maxTapDistance"
        static let palmRejectionMargin = "palmRejectionMargin"
        static let autoscrollEnabled = "autoscrollEnabled"
        static let legacyAutoscrollMode = "autoscrollMode"
        static let autoscrollBrowsersOnly = "autoscrollBrowsersOnly"
        static let autoscrollForPhysicalMouse = "autoscrollForPhysicalMouse"
        static let autoscrollSpeed = "autoscrollSpeed"
        static let autoscrollDeadzone = "autoscrollDeadzone"
        static let autoscrollDragThreshold = "autoscrollDragThreshold"
        static let autoscrollHorizontalEnabled = "autoscrollHorizontalEnabled"
        static let autoscrollInvertDirection = "autoscrollInvertDirection"
        static let ignoredAppBundles = "ignoredAppBundles"
        static let autoscrollIgnoredBundles = "autoscrollIgnoredBundles"
    }

    @Published public var language: AppLanguage { didSet { saveAndSync() } }
    @Published public var isEnabled: Bool { didSet { saveAndSync() } }
    @Published public var minimumFingers: Int { didSet { saveAndSync() } }
    @Published public var allowMoreFingers: Bool { didSet { saveAndSync() } }
    @Published public var tapToClick: Bool { didSet { saveAndSync() } }
    @Published public var maxTapDurationMs: Double { didSet { saveAndSync() } }
    @Published public var maxTapDistance: Float { didSet { saveAndSync() } }
    @Published public var palmRejectionMargin: Float { didSet { saveAndSync() } }
    @Published public var autoscrollEnabled: Bool { didSet { saveAndSync() } }
    @Published public var autoscrollBrowsersOnly: Bool { didSet { saveAndSync() } }
    @Published public var autoscrollForPhysicalMouse: Bool { didSet { saveAndSync() } }
    @Published public var autoscrollSpeed: Double { didSet { saveAndSync() } }
    @Published public var autoscrollDeadzone: Double { didSet { saveAndSync() } }
    @Published public var autoscrollDragThreshold: Double { didSet { saveAndSync() } }
    @Published public var autoscrollHorizontalEnabled: Bool { didSet { saveAndSync() } }
    @Published public var autoscrollInvertDirection: Bool { didSet { saveAndSync() } }
    @Published public var ignoredAppBundles: Set<String> { didSet { saveAndSync() } }
    @Published public var autoscrollIgnoredBundles: Set<String> { didSet { saveAndSync() } }

    public var onChange: ((ConfigSnapshot) -> Void)?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let systemTap = CFPreferencesGetAppBooleanValue(
            "Clicking" as CFString,
            "com.apple.driver.AppleBluetoothMultitouch.trackpad" as CFString,
            nil
        )

        let langRaw = defaults.string(forKey: Keys.language)
        let lang = langRaw.flatMap(AppLanguage.init(rawValue:)) ?? AppLanguage.systemDefault
        let enabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        let fingers = defaults.object(forKey: Keys.minimumFingers) as? Int ?? 3
        let moreFingers = defaults.object(forKey: Keys.allowMoreFingers) as? Bool ?? false
        let tap = defaults.object(forKey: Keys.tapToClick) as? Bool ?? systemTap
        let tapDur = defaults.object(forKey: Keys.maxTapDurationMs) as? Double ?? 300.0
        let tapDist = defaults.object(forKey: Keys.maxTapDistance) as? Float ?? 0.05
        let palm = defaults.object(forKey: Keys.palmRejectionMargin) as? Float ?? 0.04
        let autoEnabled: Bool
        if let saved = defaults.object(forKey: Keys.autoscrollEnabled) as? Bool {
            autoEnabled = saved
        } else if let legacy = defaults.string(forKey: Keys.legacyAutoscrollMode) {
            autoEnabled = legacy != "off"
        } else {
            autoEnabled = true
        }
        let browsersOnly = defaults.object(forKey: Keys.autoscrollBrowsersOnly) as? Bool ?? true
        let physMouse = defaults.object(forKey: Keys.autoscrollForPhysicalMouse) as? Bool ?? true
        let speed = defaults.object(forKey: Keys.autoscrollSpeed) as? Double ?? 1.0
        let deadzone = defaults.object(forKey: Keys.autoscrollDeadzone) as? Double ?? 14.0
        let dragThresh = defaults.object(forKey: Keys.autoscrollDragThreshold) as? Double ?? 8.0
        let horiz = defaults.object(forKey: Keys.autoscrollHorizontalEnabled) as? Bool ?? true
        let invert = defaults.object(forKey: Keys.autoscrollInvertDirection) as? Bool ?? false
        let ignored = Set(defaults.stringArray(forKey: Keys.ignoredAppBundles) ?? [])
        let autoIgnored = Set(defaults.stringArray(forKey: Keys.autoscrollIgnoredBundles) ?? [])

        self.language = lang
        self.isEnabled = enabled
        self.minimumFingers = max(2, min(10, fingers))
        self.allowMoreFingers = moreFingers
        self.tapToClick = tap
        self.maxTapDurationMs = tapDur
        self.maxTapDistance = tapDist
        self.palmRejectionMargin = palm
        self.autoscrollEnabled = autoEnabled
        self.autoscrollBrowsersOnly = browsersOnly
        self.autoscrollForPhysicalMouse = physMouse
        self.autoscrollSpeed = speed
        self.autoscrollDeadzone = deadzone
        self.autoscrollDragThreshold = dragThresh
        self.autoscrollHorizontalEnabled = horiz
        self.autoscrollInvertDirection = invert
        self.ignoredAppBundles = ignored
        self.autoscrollIgnoredBundles = autoIgnored

        self._snapshot = ConfigSnapshot(
            isEnabled: enabled,
            minimumFingers: max(2, min(10, fingers)),
            allowMoreFingers: moreFingers,
            tapToClick: tap,
            maxTapDurationSec: tapDur / 1000.0,
            maxTapDistance: tapDist,
            palmRejectionMargin: palm,
            autoscrollEnabled: autoEnabled,
            autoscrollBrowsersOnly: browsersOnly,
            autoscrollForPhysicalMouse: physMouse,
            autoscrollSpeed: speed,
            autoscrollDeadzone: deadzone,
            autoscrollDragThreshold: dragThresh,
            autoscrollHorizontalEnabled: horiz,
            autoscrollInvertDirection: invert,
            ignoredAppBundles: ignored,
            autoscrollIgnoredBundles: autoIgnored
        )
    }

    public var snapshot: ConfigSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return _snapshot
    }

    public func toggleIgnoredApp(_ bundleID: String) {
        if ignoredAppBundles.contains(bundleID) {
            ignoredAppBundles.remove(bundleID)
        } else {
            ignoredAppBundles.insert(bundleID)
        }
    }

    public func toggleAutoscrollIgnoredApp(_ bundleID: String) {
        if autoscrollIgnoredBundles.contains(bundleID) {
            autoscrollIgnoredBundles.remove(bundleID)
        } else {
            autoscrollIgnoredBundles.insert(bundleID)
        }
    }

    public func resetDefaults() {
        isEnabled = true
        minimumFingers = 3
        allowMoreFingers = false
        tapToClick = CFPreferencesGetAppBooleanValue(
            "Clicking" as CFString,
            "com.apple.driver.AppleBluetoothMultitouch.trackpad" as CFString,
            nil
        )
        maxTapDurationMs = 300.0
        maxTapDistance = 0.05
        palmRejectionMargin = 0.04
        autoscrollEnabled = true
        autoscrollBrowsersOnly = true
        autoscrollForPhysicalMouse = true
        autoscrollSpeed = 1.0
        autoscrollDeadzone = 14.0
        autoscrollDragThreshold = 8.0
        autoscrollHorizontalEnabled = true
        autoscrollInvertDirection = false
    }

    private func saveAndSync() {
        defaults.set(language.rawValue, forKey: Keys.language)
        defaults.set(isEnabled, forKey: Keys.isEnabled)
        defaults.set(minimumFingers, forKey: Keys.minimumFingers)
        defaults.set(allowMoreFingers, forKey: Keys.allowMoreFingers)
        defaults.set(tapToClick, forKey: Keys.tapToClick)
        defaults.set(maxTapDurationMs, forKey: Keys.maxTapDurationMs)
        defaults.set(maxTapDistance, forKey: Keys.maxTapDistance)
        defaults.set(palmRejectionMargin, forKey: Keys.palmRejectionMargin)
        defaults.set(autoscrollEnabled, forKey: Keys.autoscrollEnabled)
        defaults.set(autoscrollBrowsersOnly, forKey: Keys.autoscrollBrowsersOnly)
        defaults.set(autoscrollForPhysicalMouse, forKey: Keys.autoscrollForPhysicalMouse)
        defaults.set(autoscrollSpeed, forKey: Keys.autoscrollSpeed)
        defaults.set(autoscrollDeadzone, forKey: Keys.autoscrollDeadzone)
        defaults.set(autoscrollDragThreshold, forKey: Keys.autoscrollDragThreshold)
        defaults.set(autoscrollHorizontalEnabled, forKey: Keys.autoscrollHorizontalEnabled)
        defaults.set(autoscrollInvertDirection, forKey: Keys.autoscrollInvertDirection)
        defaults.set(Array(ignoredAppBundles).sorted(), forKey: Keys.ignoredAppBundles)
        defaults.set(Array(autoscrollIgnoredBundles).sorted(), forKey: Keys.autoscrollIgnoredBundles)

        let snap = ConfigSnapshot(
            isEnabled: isEnabled,
            minimumFingers: minimumFingers,
            allowMoreFingers: allowMoreFingers,
            tapToClick: tapToClick,
            maxTapDurationSec: maxTapDurationMs / 1000.0,
            maxTapDistance: maxTapDistance,
            palmRejectionMargin: palmRejectionMargin,
            autoscrollEnabled: autoscrollEnabled,
            autoscrollBrowsersOnly: autoscrollBrowsersOnly,
            autoscrollForPhysicalMouse: autoscrollForPhysicalMouse,
            autoscrollSpeed: autoscrollSpeed,
            autoscrollDeadzone: autoscrollDeadzone,
            autoscrollDragThreshold: autoscrollDragThreshold,
            autoscrollHorizontalEnabled: autoscrollHorizontalEnabled,
            autoscrollInvertDirection: autoscrollInvertDirection,
            ignoredAppBundles: ignoredAppBundles,
            autoscrollIgnoredBundles: autoscrollIgnoredBundles
        )

        lock.lock()
        _snapshot = snap
        lock.unlock()

        onChange?(snap)
    }
}
