import Foundation

/// Foutdomein voor de PM5-laag. Volgt de naamgeving uit sectie 59 van het
/// masterdocument. Protocolonzekerheid resulteert altijd in een expliciete
/// fout hier, nooit in een gok die als correcte bytes wordt verstuurd.
public enum PM5Error: Error, Equatable, Sendable {
    /// De workoutstructuur bevat iets waarvoor de programmeersequentie nog
    /// niet is bevestigd (bijv. undefined rest, warm-up/cooldown-intervallen,
    /// een target-metric die de PM5 niet ondersteunt, of een werkstap zonder
    /// bijbehorende rust). Zie `PM5WorkoutProgrammer` voor precies wat wél
    /// ondersteund is.
    case unsupportedWorkoutConfiguration(reason: String)

    case csafeFrameError(CSAFEFrameError)
}

extension PM5Error: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedWorkoutConfiguration(let reason):
            return "Deze workoutstructuur wordt nog niet ondersteund voor PM5-programmering: \(reason)"
        case .csafeFrameError(let underlying):
            return "CSAFE-frame-fout: \(underlying)"
        }
    }
}
