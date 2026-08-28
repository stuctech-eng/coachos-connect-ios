import Foundation

/// Spiegelt CoachOS' `WorkoutTarget` (`src/core/workout-builder/types.ts`)
/// exact, veld voor veld — geverifieerd tegen de daadwerkelijke repository
/// tijdens de contract-review (28 augustus 2026).
public struct CoachOSWorkoutTargetDTO: Decodable, Equatable, Sendable {
    public let type: String
    public let waarde: Double?
    public let van: Double?
    public let tot: Double?
    public let zoneNummer: Int?

    enum CodingKeys: String, CodingKey {
        case type, waarde, van, tot
        case zoneNummer = "zone_nummer"
    }
}

/// Spiegelt CoachOS' `WorkoutBlock`.
public struct CoachOSWorkoutBlockDTO: Decodable, Equatable, Sendable {
    public let id: String
    public let type: String
    public let durationSec: Int
    public let distanceM: Double?
    public let repeatCount: Int?
    public let restNaRepeatSec: Int?
    public let targets: [CoachOSWorkoutTargetDTO]
    public let instruction: String
    public let coachMessage: String?

    enum CodingKeys: String, CodingKey {
        case id, type, targets, instruction, coachMessage
        case durationSec = "duration_sec"
        case distanceM = "distance_m"
        case repeatCount = "repeat"
        case restNaRepeatSec = "rust_na_repeat_sec"
    }
}

/// Spiegelt CoachOS' centrale `UniversalWorkout`
/// (`src/core/workout-builder/types.ts`). Bevat uitsluitend de velden die
/// Connect gebruikt voor de mapping naar zijn eigen `UniversalWorkout` —
/// `coachNotes`/`executionHints`/`equipment`/`metrics`/`adaptations`/
/// `kruisSportBron`/`alternatives` worden bewust niet gemodelleerd (nog
/// geen Connect-gebruik ervoor), `Decodable` negeert ze automatisch.
public struct CoachOSUniversalWorkoutDTO: Decodable, Equatable, Sendable {
    public let id: String
    public let sport: String
    public let executionType: String
    public let warmup: [CoachOSWorkoutBlockDTO]
    public let mainBlocks: [CoachOSWorkoutBlockDTO]
    public let recoveryBlocks: [CoachOSWorkoutBlockDTO]
    public let cooldown: [CoachOSWorkoutBlockDTO]
}

/// De workout-route retourneert bij een reguliere trainingsdag
/// `{ workout, validatie, uitvoeringsHints, materiaal, vertaaldeBlokken,
/// alternatieven }`, maar bij een rustdag-beslissing in plaats daarvan
/// `{ rest: true, reasons: [...] }` — bevestigd in
/// `api/specialists/rowing/training-plan/workout/route.ts`. Beide vormen
/// hier gemodelleerd, alle velden optioneel zodat één DTO volstaat voor
/// het onderscheiden van de twee gevallen.
public struct CoachOSWorkoutRouteResponseDTO: Decodable, Equatable, Sendable {
    public let workout: CoachOSUniversalWorkoutDTO?
    public let rest: Bool?
    public let reasons: [String]?
}
