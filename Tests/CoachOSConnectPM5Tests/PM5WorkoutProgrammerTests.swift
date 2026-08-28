import XCTest
import CoachOSConnectCore
@testable import CoachOSConnectPM5

final class PM5WorkoutProgrammerTests: XCTestCase {

    /// Het bevestigde MVP-doel (sectie 54 masterdocument): 5×(4:00 werk @
    /// 220W, 2:00 rust).
    func test_program_confirmedMVPWorkout_producesFiveCorrectIntervalBlocks() throws {
        let work = WorkoutStep(
            name: "Werk",
            kind: .work,
            duration: .time(seconds: 240),
            targets: [WorkoutTarget(metric: .power, minValue: 220)]
        )
        let recovery = WorkoutStep(name: "Rust", kind: .recovery, duration: .time(seconds: 120))

        let workout = UniversalWorkout(
            sourceId: "test",
            title: "5x4/2",
            sport: .rowing,
            blocks: [.repeatGroup(RepeatGroup(count: 5, steps: [work, recovery]))]
        )

        let blocks = try PM5WorkoutProgrammer.program(workout)

        XCTAssertEqual(blocks.count, 5)
        XCTAssertEqual(blocks.map(\.index), [0, 1, 2, 3, 4])

        let firstBlock = blocks[0]
        XCTAssertEqual(firstBlock.commands, [
            .setWorkoutIntervalCount(0),
            .setIntervalType(PM5IntervalType.time),
            .setWorkoutDuration(durationType: PM5DurationType.time, value: 24000),
            .setRestDuration(seconds: 120),
            .setTargetAverageWatts(220),
            .configureWorkout(programmingMode: true)
        ])

        let lastBlock = blocks[4]
        XCTAssertEqual(lastBlock.index, 4)
    }

    func test_program_paceTarget_appliesConfirmedUnitConvention() throws {
        // 1:40/500m pace-doel → 100 sec * 100 = 10000 (bevestigd ErgometerJS-voorbeeld).
        let work = WorkoutStep(
            name: "Werk",
            kind: .work,
            duration: .time(seconds: 240),
            targets: [WorkoutTarget(metric: .pace, minValue: 100)]
        )
        let recovery = WorkoutStep(name: "Rust", kind: .recovery, duration: .time(seconds: 120))
        let workout = UniversalWorkout(sourceId: "t", title: "t", sport: .rowing, blocks: [.step(work), .step(recovery)])

        let blocks = try PM5WorkoutProgrammer.program(workout)

        XCTAssertTrue(blocks[0].commands.contains(.setTargetPaceTime(centiseconds: 10000)))
    }

    func test_program_onlyWarmupNoWorkIntervals_throwsUnsupported() {
        let warmup = WorkoutStep(name: "Warm-up", kind: .warmup, duration: .time(seconds: 300))
        let workout = UniversalWorkout(sourceId: "t", title: "t", sport: .rowing, blocks: [.step(warmup)])

        XCTAssertThrowsError(try PM5WorkoutProgrammer.program(workout)) { error in
            guard case PM5Error.unsupportedWorkoutConfiguration = error else {
                return XCTFail("Verwachtte unsupportedWorkoutConfiguration, kreeg \(error)")
            }
        }
    }

    /// Sprint 6b-2-correctie: dit is de realistische vorm van een echte
    /// CoachOS-workout (warmup + intervallen + cooldown) — moet nu wél
    /// slagen, warmup/cooldown worden overgeslagen, niet de hele workout
    /// geweigerd.
    func test_program_realisticWorkoutWithWarmupAndCooldown_succeeds() throws {
        let warmup = WorkoutStep(name: "Warm-up", kind: .warmup, duration: .time(seconds: 300))
        let work = WorkoutStep(
            name: "Werk",
            kind: .work,
            duration: .time(seconds: 240),
            targets: [WorkoutTarget(metric: .power, minValue: 220)]
        )
        let recovery = WorkoutStep(name: "Rust", kind: .recovery, duration: .time(seconds: 120))
        let cooldown = WorkoutStep(name: "Cooldown", kind: .cooldown, duration: .time(seconds: 300))

        let workout = UniversalWorkout(
            sourceId: "t", title: "t", sport: .rowing,
            blocks: [
                .step(warmup),
                .repeatGroup(RepeatGroup(count: 5, steps: [work, recovery])),
                .step(cooldown)
            ]
        )

        let blocks = try PM5WorkoutProgrammer.program(workout)

        XCTAssertEqual(blocks.count, 5)
        XCTAssertEqual(blocks.map(\.index), [0, 1, 2, 3, 4])
    }

    func test_program_workWithoutFollowingRecovery_throwsUnsupported() {
        let work = WorkoutStep(name: "Werk", kind: .work, duration: .time(seconds: 240))
        let workout = UniversalWorkout(sourceId: "t", title: "t", sport: .rowing, blocks: [.step(work)])

        XCTAssertThrowsError(try PM5WorkoutProgrammer.program(workout)) { error in
            guard case PM5Error.unsupportedWorkoutConfiguration = error else {
                return XCTFail("Verwachtte unsupportedWorkoutConfiguration, kreeg \(error)")
            }
        }
    }

    func test_program_openEndedRestDuration_throwsUnsupported_ratherThanGuessIntervalType() {
        let work = WorkoutStep(name: "Werk", kind: .work, duration: .time(seconds: 240))
        let undefinedRest = WorkoutStep(name: "Rust", kind: .recovery, duration: .openEnded)
        let workout = UniversalWorkout(sourceId: "t", title: "t", sport: .rowing, blocks: [.step(work), .step(undefinedRest)])

        XCTAssertThrowsError(try PM5WorkoutProgrammer.program(workout)) { error in
            guard case PM5Error.unsupportedWorkoutConfiguration = error else {
                return XCTFail("Verwachtte unsupportedWorkoutConfiguration, kreeg \(error)")
            }
        }
    }

    func test_program_distanceBasedWork_throwsUnsupported() {
        let work = WorkoutStep(name: "Werk", kind: .work, duration: .distance(meters: 500))
        let recovery = WorkoutStep(name: "Rust", kind: .recovery, duration: .time(seconds: 120))
        let workout = UniversalWorkout(sourceId: "t", title: "t", sport: .rowing, blocks: [.step(work), .step(recovery)])

        XCTAssertThrowsError(try PM5WorkoutProgrammer.program(workout)) { error in
            guard case PM5Error.unsupportedWorkoutConfiguration = error else {
                return XCTFail("Verwachtte unsupportedWorkoutConfiguration, kreeg \(error)")
            }
        }
    }

    func test_program_unsupportedTargetMetric_throwsUnsupported() {
        let work = WorkoutStep(
            name: "Werk",
            kind: .work,
            duration: .time(seconds: 240),
            targets: [WorkoutTarget(metric: .heartRate, minValue: 150)]
        )
        let recovery = WorkoutStep(name: "Rust", kind: .recovery, duration: .time(seconds: 120))
        let workout = UniversalWorkout(sourceId: "t", title: "t", sport: .rowing, blocks: [.step(work), .step(recovery)])

        XCTAssertThrowsError(try PM5WorkoutProgrammer.program(workout)) { error in
            guard case PM5Error.unsupportedWorkoutConfiguration = error else {
                return XCTFail("Verwachtte unsupportedWorkoutConfiguration, kreeg \(error)")
            }
        }
    }

    func test_program_emptyWorkout_throwsUnsupported() {
        let workout = UniversalWorkout(sourceId: "t", title: "t", sport: .rowing, blocks: [])
        XCTAssertThrowsError(try PM5WorkoutProgrammer.program(workout))
    }
}
