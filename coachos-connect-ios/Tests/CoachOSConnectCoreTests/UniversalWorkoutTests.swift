import XCTest
@testable import CoachOSConnectCore

final class UniversalWorkoutTests: XCTestCase {

    func test_universalWorkout_isCodable() throws {
        let warmup = WorkoutStep(
            name: "Warm-up",
            kind: .warmup,
            duration: .time(seconds: 300),
            targets: [WorkoutTarget(metric: .power, minValue: 100, maxValue: 140)]
        )
        let work = WorkoutStep(
            name: "Interval",
            kind: .interval,
            duration: .distance(meters: 500),
            targets: [WorkoutTarget(metric: .power, minValue: 220, maxValue: 240)]
        )
        let recovery = WorkoutStep(name: "Recovery", kind: .recovery, duration: .time(seconds: 120))

        let workout = UniversalWorkout(
            sourceId: "abc123",
            title: "Test Interval",
            sport: .rowing,
            blocks: [
                .step(warmup),
                .repeatGroup(RepeatGroup(count: 5, steps: [work, recovery]))
            ]
        )

        let data = try JSONEncoder().encode(workout)
        let decoded = try JSONDecoder().decode(UniversalWorkout.self, from: data)

        XCTAssertEqual(decoded, workout)
        // 1 warm-up + 5x (work + recovery) = 11 uitgerolde stappen
        XCTAssertEqual(decoded.expandedSteps.count, 11)
    }

    func test_deviceStateMachine_allowsValidWorkoutFlow() {
        XCTAssertTrue(DeviceStateMachine.canTransition(from: .disconnected, to: .scanning))
        XCTAssertTrue(DeviceStateMachine.canTransition(from: .connecting, to: .connected))
        XCTAssertTrue(DeviceStateMachine.canTransition(from: .connected, to: .workoutLoaded))
        XCTAssertTrue(DeviceStateMachine.canTransition(from: .workoutLoaded, to: .running))
        XCTAssertTrue(DeviceStateMachine.canTransition(from: .running, to: .paused))
        XCTAssertTrue(DeviceStateMachine.canTransition(from: .paused, to: .running))
        XCTAssertTrue(DeviceStateMachine.canTransition(from: .running, to: .finished))
        XCTAssertTrue(DeviceStateMachine.canTransition(from: .finished, to: .syncing))
    }

    func test_deviceStateMachine_rejectsInvalidWorkoutFlow() {
        // Je kunt niet rechtstreeks van verbonden naar hervatten springen
        // zonder ooit een workout geladen of gestart te hebben.
        XCTAssertFalse(DeviceStateMachine.canTransition(from: .connected, to: .running))
        XCTAssertFalse(DeviceStateMachine.canTransition(from: .workoutLoaded, to: .paused))
        XCTAssertFalse(DeviceStateMachine.canTransition(from: .disconnected, to: .running))
    }

    func test_startWorkoutUseCase_throwsWhenDeviceNotConnected() async {
        let adapter = StubDeviceAdapter(state: .disconnected)
        let useCase = StartWorkoutUseCase(adapter: adapter)
        let workout = UniversalWorkout(sourceId: "x", title: "x", sport: .cycling, blocks: [])

        do {
            try await useCase.execute(workout: workout)
            XCTFail("Verwachtte CoachOSConnectError.deviceNotConnected")
        } catch CoachOSConnectError.deviceNotConnected {
            // verwacht
        } catch {
            XCTFail("Onverwachte fout: \(error)")
        }
    }
}

/// Testdubbel die aantoont dat use cases volledig los van echte hardware
/// getest kunnen worden — precies wat het `DeviceAdapterProtocol` mogelijk
/// maakt.
private final class StubDeviceAdapter: DeviceAdapterProtocol {
    let descriptor = DeviceDescriptor(id: "stub", manufacturer: "Stub", model: "Stub", capabilities: [])
    let state: DeviceState

    init(state: DeviceState) {
        self.state = state
    }

    func capabilities() -> Set<DeviceCapability> { [] }
    func connect() async throws {}
    func disconnect() async throws {}
    func sendWorkout(_ workout: UniversalWorkout) async throws {}
    func startWorkout() async throws {}
    func pauseWorkout() async throws {}
    func resumeWorkout() async throws {}
    func stopWorkout() async throws {}
    func metricsStream() -> AsyncStream<LiveMetricsBatch> { AsyncStream { $0.finish() } }
    func sync() async throws {}
    func batteryLevel() async -> Int? { nil }
}
