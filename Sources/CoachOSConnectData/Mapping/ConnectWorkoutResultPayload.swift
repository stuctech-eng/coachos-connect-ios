import Foundation

/// Exacte spiegel van het request-body-schema dat
/// `POST /api/specialists/rowing/training-plan/workout-result` verwacht
/// (`connect-result-bridge.ts`/`workout-result/route.ts`, Sprint 6b-3
/// backend, 28 augustus 2026). Geen eigen interpretatie — dit is
/// letterlijk het contract zoals geïmplementeerd en geverifieerd op de
/// live CoachOS-repository, veld voor veld.
///
/// Let op de gemengde naamgeving (bewust ongewijzigd overgenomen, niet
/// "verbeterd"): top-level velden camelCase (`sessieId`, `startedAt`),
/// binnen `totals`/`intervals` snake_case (`distance_m`, `avg_watts`) —
/// zo staat het in de backend-route, dus zo wordt het hier verstuurd.
public struct ConnectWorkoutResultPayload: Encodable, Equatable, Sendable {
    public let sessieId: String
    public let startedAt: Date
    public let completedAt: Date
    public let device: Device
    public let totals: Totals?
    public let intervals: [Interval]?

    public struct Device: Encodable, Equatable, Sendable {
        public let manufacturer: String
        public let model: String

        public init(manufacturer: String, model: String) {
            self.manufacturer = manufacturer
            self.model = model
        }
    }

    public struct Totals: Encodable, Equatable, Sendable {
        public let distanceM: Double?
        public let avgWatts: Double?
        public let avgStrokeRate: Double?
        public let avgHeartRate: Double?

        enum CodingKeys: String, CodingKey {
            case distanceM = "distance_m"
            case avgWatts = "avg_watts"
            case avgStrokeRate = "avg_stroke_rate"
            case avgHeartRate = "avg_heart_rate"
        }

        public init(distanceM: Double? = nil, avgWatts: Double? = nil, avgStrokeRate: Double? = nil, avgHeartRate: Double? = nil) {
            self.distanceM = distanceM
            self.avgWatts = avgWatts
            self.avgStrokeRate = avgStrokeRate
            self.avgHeartRate = avgHeartRate
        }
    }

    public struct Interval: Encodable, Equatable, Sendable {
        public let index: Int
        public let distanceM: Double?
        public let durationSec: Int?
        public let avgPaceSecPer500m: Double?
        public let avgWatts: Double?
        public let avgStrokeRate: Double?

        enum CodingKeys: String, CodingKey {
            case index
            case distanceM = "distance_m"
            case durationSec = "duration_sec"
            case avgPaceSecPer500m = "avg_pace_sec_per_500m"
            case avgWatts = "avg_watts"
            case avgStrokeRate = "avg_stroke_rate"
        }

        public init(index: Int, distanceM: Double? = nil, durationSec: Int? = nil, avgPaceSecPer500m: Double? = nil, avgWatts: Double? = nil, avgStrokeRate: Double? = nil) {
            self.index = index
            self.distanceM = distanceM
            self.durationSec = durationSec
            self.avgPaceSecPer500m = avgPaceSecPer500m
            self.avgWatts = avgWatts
            self.avgStrokeRate = avgStrokeRate
        }
    }

    public init(sessieId: String, startedAt: Date, completedAt: Date, device: Device, totals: Totals? = nil, intervals: [Interval]? = nil) {
        self.sessieId = sessieId
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.device = device
        self.totals = totals
        self.intervals = intervals
    }
}
