import Foundation
import CoachOSConnectCore

/// Houdt de laatst opgehaalde workout(s) lokaal beschikbaar, zodat een
/// training ook zonder actieve internetverbinding gestart kan worden
/// ("Offline Engine" uit de architectuurvisie). Sprint 1 levert de
/// structuur; de daadwerkelijke offline-uitvoering van een workout hoort
/// bij de Workout Execution Engine in een latere sprint.
public actor WorkoutCache {
    private let storage: LocalStorageProtocol
    private let todaysWorkoutKey = "todays_workout"

    public init(storage: LocalStorageProtocol) {
        self.storage = storage
    }

    public func cache(_ workout: UniversalWorkout) async throws {
        try await storage.save(workout, forKey: todaysWorkoutKey)
    }

    public func cachedTodaysWorkout() async throws -> UniversalWorkout? {
        try await storage.load(UniversalWorkout.self, forKey: todaysWorkoutKey)
    }

    public func clear() async throws {
        try await storage.delete(forKey: todaysWorkoutKey)
    }
}
