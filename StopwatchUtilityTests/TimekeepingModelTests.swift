import XCTest
@testable import StopwatchUtility

@MainActor
final class TimekeepingModelTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: #function)
        defaults.removePersistentDomain(forName: #function)
    }

    func testStopwatchUsesAbsoluteElapsedTime() {
        let start = Date(timeIntervalSince1970: 1_000)
        let model = TimekeepingModel(defaults: defaults, now: start)

        model.toggleStopwatch()
        model.tick(at: start.addingTimeInterval(65.43))

        XCTAssertEqual(model.stopwatchElapsed, 65.43, accuracy: 0.001)
        model.toggleStopwatch()
        XCTAssertEqual(model.stopwatchElapsed, 65.43, accuracy: 0.001)
    }

    func testTimerCompletesAfterEndDate() {
        let start = Date(timeIntervalSince1970: 2_000)
        let model = TimekeepingModel(defaults: defaults, now: start)
        model.setTimerDuration(hours: 0, minutes: 0, seconds: 10)

        model.toggleTimer()
        model.tick(at: start.addingTimeInterval(11))

        XCTAssertEqual(model.displayedTimerRemaining, 0)
        XCTAssertFalse(model.isTimerRunning)
        XCTAssertEqual(model.completionMessage, "Timer complete")
    }

    func testRunningStateSurvivesRelaunch() {
        let start = Date(timeIntervalSince1970: 3_000)
        var model: TimekeepingModel? = TimekeepingModel(defaults: defaults, now: start)
        model?.toggleStopwatch()
        model?.persist()
        model = nil

        let restored = TimekeepingModel(defaults: defaults, now: start.addingTimeInterval(42))

        XCTAssertTrue(restored.isStopwatchRunning)
        XCTAssertEqual(restored.stopwatchElapsed, 42, accuracy: 0.001)
    }

    func testBehaviorModesRemainMutuallyExclusive() {
        let model = TimekeepingModel(defaults: defaults)
        model.behavior = .alwaysOnTop
        XCTAssertEqual(model.behavior, .alwaysOnTop)
        model.behavior = .autoHide
        XCTAssertEqual(model.behavior, .autoHide)
    }

    func testParsesKeyboardTimerDurations() {
        XCTAssertEqual(TimekeepingModel.parseTimerDuration("25:30"), 1_530)
        XCTAssertEqual(TimekeepingModel.parseTimerDuration("1:02:03"), 3_723)
        XCTAssertEqual(TimekeepingModel.parseTimerDuration(" 90:00 "), 5_400)
    }

    func testRejectsInvalidKeyboardTimerDurations() {
        XCTAssertNil(TimekeepingModel.parseTimerDuration("25"))
        XCTAssertNil(TimekeepingModel.parseTimerDuration("1:60:00"))
        XCTAssertNil(TimekeepingModel.parseTimerDuration("10:99"))
        XCTAssertNil(TimekeepingModel.parseTimerDuration("hello"))
    }

    func testQuickAdjustChangesStoppedCountdownAndClamps() {
        let model = TimekeepingModel(defaults: defaults)
        model.setTimerDuration(hours: 0, minutes: 1, seconds: 0)

        model.adjustTimer(by: 300)
        XCTAssertEqual(model.displayedTimerRemaining, 360)

        model.adjustTimer(by: -1_000)
        XCTAssertEqual(model.displayedTimerRemaining, 0)
    }

    func testResetTimerStopsAndClearsCountdown() {
        let start = Date(timeIntervalSince1970: 4_000)
        let model = TimekeepingModel(defaults: defaults, now: start)
        model.setTimerDuration(hours: 0, minutes: 25, seconds: 0)
        model.toggleTimer()
        model.tick(at: start.addingTimeInterval(5))

        model.resetTimer()

        XCTAssertFalse(model.isTimerRunning)
        XCTAssertEqual(model.timerDuration, 0)
        XCTAssertEqual(model.displayedTimerRemaining, 0)
    }

    func testHideCountdownStartsDisabledOnEveryLaunch() {
        var model: TimekeepingModel? = TimekeepingModel(defaults: defaults)
        model?.hideCountdownWhenIdle = true
        model?.persist()
        model = nil

        let restored = TimekeepingModel(defaults: defaults)

        XCTAssertFalse(restored.hideCountdownWhenIdle)
    }
}
