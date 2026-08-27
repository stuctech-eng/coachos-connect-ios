import Foundation

/// Use cases bevatten toepassingslogica: ze orkestreren repositories en
/// (via de Device Layer) adapters, maar kennen zelf geen implementatiedetails
/// (geen networking, geen Bluetooth, geen persistence). Dat is precies wat
/// Clean Architecture hier oplevert: de UI-laag praat met use cases, nooit
/// direct met repositories of adapters.

public struct FetchTodaysWorkoutUseCase: Sendable {
    private let workoutRepository: WorkoutRepositoryProtocol

    public init(workoutRepository: WorkoutRepositoryProtocol) {
        self.workoutRepository = workoutRepository
    }

    public func execute() async throws -> UniversalWorkout? {
        try await workoutRepository.fetchTodaysWorkout()
    }
}

public struct ConnectDeviceUseCase: Sendable {
    private let adapter: DeviceAdapterProtocol

    public init(adapter: DeviceAdapterProtocol) {
        self.adapter = adapter
    }

    public func execute() async throws {
        try await adapter.connect()
    }
}

public struct StartWorkoutUseCase: Sendable {
    private let adapter: DeviceAdapterProtocol

    public init(adapter: DeviceAdapterProtocol) {
        self.adapter = adapter
    }

    public func execute(workout: UniversalWorkout) async throws {
        guard adapter.state == .connected else {
            throw CoachOSConnectError.deviceNotConnected
        }
        try await adapter.sendWorkout(workout)
        try await adapter.startWorkout()
    }
}

public struct SyncPendingItemsUseCase: Sendable {
    private let syncRepository: SyncRepositoryProtocol

    public init(syncRepository: SyncRepositoryProtocol) {
        self.syncRepository = syncRepository
    }

    public func execute() async throws {
        try await syncRepository.syncAll()
    }
}
