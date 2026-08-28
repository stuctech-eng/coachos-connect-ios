import Foundation
import CoachOSConnectCore

/// Bouwt een verzendklaar `SyncItem` (met gecodeerde
/// `ConnectWorkoutResultPayload`) van de gegevens die na een training
/// daadwerkelijk bekend zijn.
///
/// BEWUST NOG NIET GEKOPPELD aan een echte trainingssessie: er bestaat op
/// dit moment nergens in Connect een Workout Player die een training
/// daadwerkelijk van start tot finish begeleidt (dat is Sprint 9). Deze
/// builder is klaar en getest voor het moment dat die er is — tot die
/// tijd is er simpelweg geen aanroeper die 'm gebruikt, en dat is eerlijk
/// zo, geen gok naar een UI-flow die nog niet bestaat.
///
/// `totals`/`intervals` zijn optioneel en vandaag typisch afwezig: PM5
/// live metrics zijn nog niet gedecodeerd (Sprint 8,
/// `PM5Adapter.metricsStream()` geeft nu een lege stream terug) — exact
/// dezelfde eerlijke beperking als CoachOS' eigen Trainer AI-brug
/// ("EERLIJKE BEPERKING: ... metrics blijft dus leeg i.p.v. iets te
/// verzinnen").
public enum ConnectWorkoutResultBuilder {

    public static func makeSyncItem(
        sessieId: String,
        startedAt: Date,
        completedAt: Date,
        deviceManufacturer: String,
        deviceModel: String,
        totals: ConnectWorkoutResultPayload.Totals? = nil,
        intervals: [ConnectWorkoutResultPayload.Interval]? = nil
    ) throws -> SyncItem {
        let payload = ConnectWorkoutResultPayload(
            sessieId: sessieId,
            startedAt: startedAt,
            completedAt: completedAt,
            device: .init(manufacturer: deviceManufacturer, model: deviceModel),
            totals: totals,
            intervals: intervals
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(payload)

        return SyncItem(kind: .completedWorkout, payloadReference: sessieId, payload: encoded)
    }
}
