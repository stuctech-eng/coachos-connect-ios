import Foundation

/// Spiegelt CoachOS' `TodayPlan` (`src/lib/today-engine.ts`), 1-op-1
/// zoals bevestigd tijdens de contract-review (28 augustus 2026). Bevat
/// uitsluitend de velden die Connect daadwerkelijk gebruikt — CoachOS'
/// overige velden (`trainingDecision`, `trainingPhase`, ...) worden door
/// `Decodable` automatisch genegeerd, geen reden om ze hier te modelleren
/// zolang Connect ze niet nodig heeft.
public struct CoachOSTodayPlanDTO: Decodable, Equatable, Sendable {
    public let source: String
    public let sessieId: String?

    public init(source: String, sessieId: String?) {
        self.source = source
        self.sessieId = sessieId
    }
}

/// `/api/today` retourneert `{ plan: TodayPlan }`, geen kale `TodayPlan`.
public struct CoachOSTodayResponseDTO: Decodable, Equatable, Sendable {
    public let plan: CoachOSTodayPlanDTO
}
