import CoreGraphics
import XCTest
@testable import TiffyClickCore

final class TiffyClickCoreTests: XCTestCase {

    // MARK: - AutoscrollMath Tests

    func testAutoscrollWithinDeadzoneProducesZero() {
        let anchor = CGPoint(x: 500, y: 500)
        let cursor = CGPoint(x: 508, y: 510) // dx=8, dy=10 both <= deadzone 14

        let step = AutoscrollMath.computeStep(
            anchor: anchor,
            current: cursor,
            deadzone: 14,
            speedMultiplier: 1.0,
            horizontalEnabled: true,
            invertDirection: false
        )

        XCTAssertEqual(step.wheelX, 0)
        XCTAssertEqual(step.wheelY, 0)
        XCTAssertEqual(step.direction, .none)
        XCTAssertNil(step.angleRadians)
    }

    func testAutoscrollDiagonalProducesSingleContinuousAngle() {
        let anchor = CGPoint(x: 500, y: 500)
        let cursor = CGPoint(x: 550, y: 550) // 45 deg down-right -> pi/4

        let step = AutoscrollMath.computeStep(
            anchor: anchor,
            current: cursor,
            deadzone: 14,
            speedMultiplier: 1.0,
            horizontalEnabled: true,
            invertDirection: false
        )

        XCTAssertNotNil(step.angleRadians)
        XCTAssertEqual(step.angleRadians!, .pi / 4, accuracy: 0.001)
    }

    func testAutoscrollDownProducesNegativeWheelYAndDownDirection() {
        let anchor = CGPoint(x: 500, y: 500)
        let cursor = CGPoint(x: 500, y: 580) // moved down 80px

        let step = AutoscrollMath.computeStep(
            anchor: anchor,
            current: cursor,
            deadzone: 14,
            speedMultiplier: 1.0,
            horizontalEnabled: true,
            invertDirection: false
        )

        XCTAssertLessThan(step.wheelY, 0)
        XCTAssertEqual(step.wheelX, 0)
        XCTAssertTrue(step.direction.down)
        XCTAssertFalse(step.direction.up)
    }

    func testAutoscrollInvertFlipsSign() {
        let anchor = CGPoint(x: 500, y: 500)
        let cursor = CGPoint(x: 560, y: 580)

        let normal = AutoscrollMath.computeStep(
            anchor: anchor, current: cursor, deadzone: 14, speedMultiplier: 1.0,
            horizontalEnabled: true, invertDirection: false
        )
        let inverted = AutoscrollMath.computeStep(
            anchor: anchor, current: cursor, deadzone: 14, speedMultiplier: 1.0,
            horizontalEnabled: true, invertDirection: true
        )

        XCTAssertEqual(normal.wheelY, -inverted.wheelY)
        XCTAssertEqual(normal.wheelX, -inverted.wheelX)
    }

    func testAutoscrollHorizontalDisabledZeroesWheelX() {
        let anchor = CGPoint(x: 500, y: 500)
        let cursor = CGPoint(x: 620, y: 500)

        let step = AutoscrollMath.computeStep(
            anchor: anchor, current: cursor, deadzone: 14, speedMultiplier: 1.0,
            horizontalEnabled: false, invertDirection: false
        )

        XCTAssertEqual(step.wheelX, 0)
        XCTAssertFalse(step.direction.right)
    }

    func testAutoscrollSpeedIncreasesNonlinearlyWithDistance() {
        let anchor = CGPoint(x: 500, y: 500)
        let near = AutoscrollMath.computeStep(
            anchor: anchor, current: CGPoint(x: 500, y: 540), deadzone: 14,
            speedMultiplier: 1.0, horizontalEnabled: false, invertDirection: false
        )
        let far = AutoscrollMath.computeStep(
            anchor: anchor, current: CGPoint(x: 500, y: 700), deadzone: 14,
            speedMultiplier: 1.0, horizontalEnabled: false, invertDirection: false
        )

        XCTAssertGreaterThan(abs(far.wheelY), abs(near.wheelY) * 3)
    }

    // MARK: - TapGestureRecognizer Tests

    func testThreeFingerTapTriggersMiddleClick() {
        let recognizer = TapGestureRecognizer()
        let config = ConfigSnapshot(minimumFingers: 3, tapToClick: true, maxTapDurationSec: 0.30, maxTapDistance: 0.05)

        let fingers = [
            NormalizedTouchPoint(x: 0.40, y: 0.50),
            NormalizedTouchPoint(x: 0.50, y: 0.52),
            NormalizedTouchPoint(x: 0.60, y: 0.50)
        ]

        let down = recognizer.processFrame(touches: fingers, timestamp: 10.0, config: config)
        XCTAssertTrue(down.isTargetFingerCountActive)
        XCTAssertFalse(down.shouldTriggerTapMiddleClick)

        let hold = recognizer.processFrame(touches: fingers, timestamp: 10.08, config: config)
        XCTAssertTrue(hold.isTargetFingerCountActive)

        let release = recognizer.processFrame(touches: [], timestamp: 10.12, config: config)
        XCTAssertFalse(release.isTargetFingerCountActive)
        XCTAssertTrue(release.shouldTriggerTapMiddleClick)
    }

    func testTapTimeoutDoesNotTrigger() {
        let recognizer = TapGestureRecognizer()
        let config = ConfigSnapshot(minimumFingers: 3, tapToClick: true, maxTapDurationSec: 0.25, maxTapDistance: 0.05)
        let fingers = [
            NormalizedTouchPoint(x: 0.4, y: 0.5),
            NormalizedTouchPoint(x: 0.5, y: 0.5),
            NormalizedTouchPoint(x: 0.6, y: 0.5)
        ]

        _ = recognizer.processFrame(touches: fingers, timestamp: 1.0, config: config)
        let release = recognizer.processFrame(touches: [], timestamp: 1.40, config: config)
        XCTAssertFalse(release.shouldTriggerTapMiddleClick)
    }

    func testTapWithExcessiveMovementDoesNotTrigger() {
        let recognizer = TapGestureRecognizer()
        let config = ConfigSnapshot(minimumFingers: 3, tapToClick: true, maxTapDurationSec: 0.30, maxTapDistance: 0.05)
        let startFingers = [
            NormalizedTouchPoint(x: 0.3, y: 0.5),
            NormalizedTouchPoint(x: 0.4, y: 0.5),
            NormalizedTouchPoint(x: 0.5, y: 0.5)
        ]
        let movedFingers = [
            NormalizedTouchPoint(x: 0.5, y: 0.5),
            NormalizedTouchPoint(x: 0.6, y: 0.5),
            NormalizedTouchPoint(x: 0.7, y: 0.5)
        ]

        _ = recognizer.processFrame(touches: startFingers, timestamp: 1.0, config: config)
        _ = recognizer.processFrame(touches: movedFingers, timestamp: 1.08, config: config)
        let release = recognizer.processFrame(touches: [], timestamp: 1.12, config: config)
        XCTAssertFalse(release.shouldTriggerTapMiddleClick)
    }

    func testPalmRejectionFiltersEdgeTouches() {
        let recognizer = TapGestureRecognizer()
        let config = ConfigSnapshot(minimumFingers: 3, tapToClick: true, palmRejectionMargin: 0.05)

        // Two center fingers + one accidental palm touch on left edge (x = 0.02)
        let touchesWithPalm = [
            NormalizedTouchPoint(x: 0.02, y: 0.2),
            NormalizedTouchPoint(x: 0.45, y: 0.5),
            NormalizedTouchPoint(x: 0.55, y: 0.5)
        ]

        let result = recognizer.processFrame(touches: touchesWithPalm, timestamp: 2.0, config: config)
        XCTAssertFalse(result.isTargetFingerCountActive)
    }

    func testNaturalMiddleClickSuppressesImmediateTapEmulation() {
        let recognizer = TapGestureRecognizer()
        let config = ConfigSnapshot(minimumFingers: 3, tapToClick: true, maxTapDurationSec: 0.30)
        let fingers = [
            NormalizedTouchPoint(x: 0.4, y: 0.5),
            NormalizedTouchPoint(x: 0.5, y: 0.5),
            NormalizedTouchPoint(x: 0.6, y: 0.5)
        ]

        _ = recognizer.processFrame(touches: fingers, timestamp: 5.0, config: config)
        recognizer.recordNaturalMiddleClick(at: 5.05)
        let release = recognizer.processFrame(touches: [], timestamp: 5.12, config: config)
        XCTAssertFalse(release.shouldTriggerTapMiddleClick)
    }

    // MARK: - VersionComparator & Config Tests

    func testVersionComparator() {
        XCTAssertTrue(VersionComparator.isNewer("1.0.1", than: "1.0.0"))
        XCTAssertTrue(VersionComparator.isNewer("v2.0.0", than: "1.9.9"))
        XCTAssertFalse(VersionComparator.isNewer("1.0.0", than: "1.0.0"))
        XCTAssertFalse(VersionComparator.isNewer("1.0.0", than: "1.1.0"))
    }

    func testConfigPersistenceAndSnapshot() {
        let suiteName = "com.local.tiffy-click.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let config = TiffyClickConfig(defaults: defaults)
        config.minimumFingers = 4
        config.autoscrollMode = .holdOnly
        config.toggleIgnoredApp("com.figma.Desktop")

        XCTAssertEqual(config.snapshot.minimumFingers, 4)
        XCTAssertEqual(config.snapshot.autoscrollMode, .holdOnly)
        XCTAssertTrue(config.snapshot.ignoredAppBundles.contains("com.figma.Desktop"))

        let reloaded = TiffyClickConfig(defaults: defaults)
        XCTAssertEqual(reloaded.minimumFingers, 4)
        XCTAssertEqual(reloaded.autoscrollMode, .holdOnly)
        XCTAssertTrue(reloaded.ignoredAppBundles.contains("com.figma.Desktop"))

        reloaded.language = .en
        let reloadedLang = TiffyClickConfig(defaults: defaults)
        XCTAssertEqual(reloadedLang.language, .en)
        XCTAssertTrue(reloadedLang.autoscrollBrowsersOnly)
        XCTAssertEqual(L10n.t("ไทย", "English", lang: .th), "ไทย")
        XCTAssertEqual(L10n.t("ไทย", "English", lang: .en), "English")
    }

    func testBrowserRegistryRecognizesBrowsersOnly() {
        XCTAssertTrue(BrowserRegistry.isBrowser(bundleID: "com.google.Chrome"))
        XCTAssertTrue(BrowserRegistry.isBrowser(bundleID: "com.apple.Safari"))
        XCTAssertTrue(BrowserRegistry.isBrowser(bundleID: "company.thebrowser.Browser"))
        XCTAssertTrue(BrowserRegistry.isBrowser(bundleID: "com.brave.Browser"))
        XCTAssertTrue(BrowserRegistry.isBrowser(bundleID: "com.microsoft.edgemac"))
        XCTAssertTrue(BrowserRegistry.isBrowser(bundleID: "org.mozilla.firefox"))
        XCTAssertFalse(BrowserRegistry.isBrowser(bundleID: "com.microsoft.VSCode"))
        XCTAssertFalse(BrowserRegistry.isBrowser(bundleID: "com.figma.Desktop"))
        XCTAssertFalse(BrowserRegistry.isBrowser(bundleID: "com.apple.finder"))
        XCTAssertFalse(BrowserRegistry.isBrowser(bundleID: nil))
    }
}
