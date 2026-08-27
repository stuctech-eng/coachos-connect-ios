import Foundation
import CoachOSConnectCore

/// Haalt workouts op bij CoachOS en cachet ze lokaal, zodat een training ook
/// zonder verbinding beschikbaar blijft. Dit is de enige plek in de app die
/// weet dat workouts via HTTP + lokale cache tot stand komen — use cases en
/// UI kennen alleen `WorkoutRepositoryProtocol`.
public final class RemoteWorkoutRepository: WorkoutRepositoryProtocol, @unchecked Sendable {
    private let apiClient: APIClient
    private let cache: WorkoutCache

    public init(apiClient: APIClient, cache: WorkoutCache) {
        self.apiClient = apiClient
        self.cache = cache
    }

    public func fetchTodaysWorkout() async throws -> UniversalWorkout? {
        do {
            let workout: UniversalWorkout = try await apiClient.send(CoachOSEndpoints.todaysWorkout())
            try await cache.cache(workout)
            return workout
        } catch CoachOSConnectError.sessionExpired {
            throw CoachOSConnectError.sessionExpired
        } catch {
            // Offline-first: bij netwerkfouten valt de repository terug op
            // de laatst gecachete workout, indien aanwezig.
            if let cached = try await cache.cachedTodaysWorkout() {
                return cached
            }
            throw error
        }
    }

    public func fetchWorkout(id: String) async throws -> UniversalWorkout {
        try await apiClient.send(CoachOSEndpoints.workout(id: id))
    }

    public func markWorkoutCompleted(id: UUID, completedAt: Date) async throws {
        let payload = try JSONEncoder().encode(["completedAt": ISO8601DateFormatter().string(from: completedAt)])
        try await apiClient.sendWithoutResponse(CoachOSEndpoints.markCompleted(id: id.uuidString, body: payload))
    }
}
