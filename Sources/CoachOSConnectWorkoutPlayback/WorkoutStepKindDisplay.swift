import Foundation
import CoachOSConnectCore

extension WorkoutStepKind {
    /// Nederlandse weergavetekst voor de huidige fase, puur voor de UI.
    public var displayLabel: String {
        switch self {
        case .warmup: return "Warm-up"
        case .work: return "Werk"
        case .interval: return "Interval"
        case .recovery: return "Hersteld"
        case .cooldown: return "Cooldown"
        case .rest: return "Rust"
        }
    }
}
