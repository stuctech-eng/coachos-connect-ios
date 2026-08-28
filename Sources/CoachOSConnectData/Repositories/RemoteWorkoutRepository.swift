import Foundation
import CoachOSConnectCore

/// Haalt workouts op bij CoachOS en cachet ze lokaal, zodat een training ook
/// zonder verbinding beschikbaar blijft. Dit is de enige plek in de app die
/// weet dat workouts via HTTP + lokale cache tot stand komen — use cases en
/// UI kennen alleen `WorkoutRepositoryProtocol`.
///
/// Sprint 6b-2: implementeert nu de daadwerkelijke, bevestigde CoachOS-
/// keten: `GET /api/today` → `sessieId` → `GET .../training-plan/workout` →
/// `CoachOSWorkoutMapper` → Connect's eigen `UniversalWorkout`. Eerder
/// (Sprint 1 t/m 6b-1) riep dit nog een nooit-bestaand `/api/v1/connect/...`-
/// endpoint aan.
public final class RemoteWorkoutRepository: WorkoutRepositoryProtocol, @unchecked Sendable {
    private let apiClient: APIClient
    private let cache: WorkoutCache

    public init(apiClient: APIClient, cache: WorkoutCache) {
        self.apiClient = apiClient
        self.cache = cache
    }

    public func fetchTodaysWorkout() async throws -> UniversalWorkout? {
        do {
            let today: CoachOSTodayResponseDTO = try await apiClient.send(CoachOSEndpoints.today())

            guard today.plan.source == "rowing", let sessieId = today.plan.sessieId else {
                // Geen rowing-sessie vandaag (andere sport, rustdag, of
                // Trainer AI-pad) — dit is geen fout, gewoon geen
                // PM5-workout voor vandaag.
                return nil
            }

            return try await fetchWorkout(id: sessieId)
        } catch CoachOSConnectError.sessionExpired {
            throw CoachOSConnectError.sessionExpired
        } catch CoachOSConnectError.workoutNotFound {
            // Rustdag-beslissing van CoachOS' eigen Coach Decision-laag —
            // geen workout, geen fout, en geen reden om terug te vallen op
            // een verouderde gecachete workout van een vorige trainingsdag.
            return nil
        } catch {
            // Offline-first: bij netwerk-, decodeer- of mappingfouten valt
            // de repository terug op de laatst gecachete workout, indien
            // aanwezig.
            if let cached = try await cache.cachedTodaysWorkout() {
                return cached
            }
            throw error
        }
    }

    public func fetchWorkout(id: String) async throws -> UniversalWorkout {
        let response: CoachOSWorkoutRouteResponseDTO = try await apiClient.send(CoachOSEndpoints.rowingWorkout(sessieId: id))

        if response.rest == true {
            // Rustdag-beslissing van CoachOS' eigen Coach Decision-laag —
            // geen workout om te programmeren, geen fout.
            throw CoachOSConnectError.workoutNotFound(id: id)
        }

        guard let workoutDTO = response.workout else {
            throw CoachOSConnectError.workoutNotFound(id: id)
        }

        let workout = try mapOrThrow(workoutDTO)
        try await cache.cache(workout)
        return workout
    }

    public func markWorkoutCompleted(id: UUID, completedAt: Date) async throws {
        let payload = try JSONEncoder().encode(["completedAt": ISO8601DateFormatter().string(from: completedAt)])
        try await apiClient.sendWithoutResponse(CoachOSEndpoints.markCompleted(id: id.uuidString, body: payload))
    }

    private func mapOrThrow(_ dto: CoachOSUniversalWorkoutDTO) throws -> UniversalWorkout {
        do {
            return try CoachOSWorkoutMapper.map(dto)
        } catch let error as CoachOSMappingError {
            throw CoachOSConnectError.unknown(reason: error.localizedDescription ?? "Kon CoachOS-workout niet vertalen.")
        }
    }
}
