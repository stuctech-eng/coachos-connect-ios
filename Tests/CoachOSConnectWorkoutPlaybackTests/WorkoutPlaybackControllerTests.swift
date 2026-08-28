import XCTest
import CoachOSConnectCore
@testable import CoachOSConnectWorkoutPlayback

final class WorkoutPlaybackControllerTests: XCTestCase {

    /// Fake klok: `advance(by:)` verzet de tijd zonder echt te wachten —
    /// deterministische tests, geen `Task.sleep` nodig.
    private final class FakeClock {
        var current: Date = Date(timeIntervalSince1970: 0)
        func advance(by seconds: TimeInterval) { current.addTimeInterval(seconds) }
        func now() -> Date { current }
    }

    private func makeWorkout(blocks: [WorkoutBlock]) -> UniversalWorkout {
        UniversalWorkout(sourceId: "t", title: "t", sport: .rowing, blocks: blocks)
    }

    func test_start_showsFirstStepImmediately() {
        let clock = FakeClock()
        let work = WorkoutStep(name: "Werk", kind: .work, duration: .time(seconds: 240), instruction: "SPM 24-26")
        let workout = makeWorkout(blocks: [.step(work)])
        let controller = WorkoutPlaybackController(workout: workout, now: clock.now)

        controller.start()

        XCTAssertEqual(controller.display?.stepIndex, 0)
        XCTAssertEqual(controller.display?.totalSteps, 1)
        XCTAssertEqual(controller.display?.step.instruction, "SPM 24-26")
        XCTAssertEqual(controller.display?.remainingSeconds, 240)
        XCTAssertTrue(controller.isRunning)
    }

    func test_tick_countsDownRemainingSecondsForTimeBasedStep() {
        let clock = FakeClock()
        let work = WorkoutStep(name: "Werk", kind: .work, duration: .time(seconds: 240))
        let workout = makeWorkout(blocks: [.step(work)])
        let controller = WorkoutPlaybackController(workout: workout, now: clock.now)

        controller.start()
        clock.advance(by: 90)
        controller.tick()

        XCTAssertEqual(controller.display?.remainingSeconds, 150)
        XCTAssertEqual(controller.display?.elapsedSeconds, 90)
    }

    func test_tick_autoAdvancesToNextStepWhenTimeExpires() {
        let clock = FakeClock()
        let work = WorkoutStep(name: "Werk", kind: .work, duration: .time(seconds: 60))
        let recovery = WorkoutStep(name: "Rust", kind: .recovery, duration: .time(seconds: 30))
        let workout = makeWorkout(blocks: [.step(work), .step(recovery)])
        let controller = WorkoutPlaybackController(workout: workout, now: clock.now)

        controller.start()
        clock.advance(by: 60)
        controller.tick()

        XCTAssertEqual(controller.display?.stepIndex, 1)
        XCTAssertEqual(controller.display?.step.kind, .recovery)
        XCTAssertEqual(controller.display?.remainingSeconds, 30)
    }

    func test_lastStepExpiring_marksWorkoutFinished() {
        let clock = FakeClock()
        let work = WorkoutStep(name: "Werk", kind: .work, duration: .time(seconds: 10))
        let workout = makeWorkout(blocks: [.step(work)])
        let controller = WorkoutPlaybackController(workout: workout, now: clock.now)

        controller.start()
        clock.advance(by: 10)
        controller.tick()

        XCTAssertTrue(controller.isFinished)
        XCTAssertNil(controller.display)
        XCTAssertFalse(controller.isRunning)
    }

    func test_distanceBasedStep_hasNoRemainingSeconds_requiresManualAdvance() {
        let clock = FakeClock()
        let work = WorkoutStep(name: "2000m", kind: .work, duration: .distance(meters: 2000))
        let cooldown = WorkoutStep(name: "Cooldown", kind: .cooldown, duration: .time(seconds: 300))
        let workout = makeWorkout(blocks: [.step(work), .step(cooldown)])
        let controller = WorkoutPlaybackController(workout: workout, now: clock.now)

        controller.start()
        clock.advance(by: 600) // ruim voorbij elke redelijke duur
        controller.tick()

        // Geen automatische afloop mogelijk zonder afstandstelemetrie —
        // blijft op stap 0 staan totdat de gebruiker zelf doorgaat.
        XCTAssertEqual(controller.display?.stepIndex, 0)
        XCTAssertNil(controller.display?.remainingSeconds)
        XCTAssertEqual(controller.display?.elapsedSeconds, 600)

        controller.advanceManually()

        XCTAssertEqual(controller.display?.stepIndex, 1)
        XCTAssertEqual(controller.display?.step.kind, .cooldown)
    }

    func test_stop_cancelsTickingWithoutResettingDisplay() {
        let clock = FakeClock()
        let work = WorkoutStep(name: "Werk", kind: .work, duration: .time(seconds: 240))
        let workout = makeWorkout(blocks: [.step(work)])
        let controller = WorkoutPlaybackController(workout: workout, now: clock.now)

        controller.start()
        controller.stop()

        XCTAssertFalse(controller.isRunning)
        XCTAssertNotNil(controller.display, "stop() moet de laatste weergave niet wegvegen")
    }

    func test_emptyWorkout_marksFinishedImmediately() {
        let workout = makeWorkout(blocks: [])
        let controller = WorkoutPlaybackController(workout: workout)

        controller.start()

        XCTAssertTrue(controller.isFinished)
        XCTAssertNil(controller.display)
    }
}

final class WorkoutStepKindDisplayTests: XCTestCase {
    func test_displayLabel_coversAllCases() {
        XCTAssertEqual(WorkoutStepKind.warmup.displayLabel, "Warm-up")
        XCTAssertEqual(WorkoutStepKind.work.displayLabel, "Werk")
        XCTAssertEqual(WorkoutStepKind.interval.displayLabel, "Interval")
        XCTAssertEqual(WorkoutStepKind.recovery.displayLabel, "Hersteld")
        XCTAssertEqual(WorkoutStepKind.cooldown.displayLabel, "Cooldown")
        XCTAssertEqual(WorkoutStepKind.rest.displayLabel, "Rust")
    }
}
