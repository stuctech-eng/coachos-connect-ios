import Foundation

/// Een hardware-onafhankelijke trainingsdefinitie zoals aangeleverd door CoachOS.
///
/// CoachOS Connect kent geen sportlogica. `UniversalWorkout` is de enige vorm
/// waarin een training de Device Layer bereikt. Elke `DeviceAdapter` is
/// verantwoordelijk voor het vertalen van deze structuur naar apparaat-specifieke
/// commando's (bijv. PM5 interval, Smart Trainer ERG, running timer).
public struct UniversalWorkout: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let sourceId: String
    public let title: String
    public let sport: WorkoutSport
    public let blocks: [WorkoutBlock]
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        sourceId: String,
        title: String,
        sport: WorkoutSport,
        blocks: [WorkoutBlock],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceId = sourceId
        self.title = title
        self.sport = sport
        self.blocks = blocks
        self.createdAt = createdAt
    }

    /// Vlakke, volledig uitgerolde lijst van stappen — elke `repeatGroup`
    /// wordt `count` keer herhaald. Bedoeld voor adapters/execution-logica
    /// die geen herhalingsstructuur hoeven te begrijpen, alleen een
    /// volgorde van uit te voeren stappen.
    ///
    /// De herhalingsstructuur zelf blijft behouden in `blocks`, voor UI die
    /// de training als "5× (4 min werk, 2 min rust)" wil tonen in plaats
    /// van 10 losse stappen.
    public var expandedSteps: [WorkoutStep] {
        blocks.flatMap { block -> [WorkoutStep] in
            switch block {
            case .step(let step):
                return [step]
            case .repeatGroup(let group):
                return Array(repeating: group.steps, count: max(group.count, 0)).flatMap { $0 }
            }
        }
    }
}

/// De sport waarvoor een workout is opgesteld. Bepaalt welke adapters
/// in aanmerking komen om de workout uit te voeren, nooit hoe dat gebeurt.
public enum WorkoutSport: String, Codable, Sendable, CaseIterable {
    case rowing
    case cycling
    case running
    case strength
    case kettlebell
    case swimming
    case unknown
}

/// Eén blok binnen een `UniversalWorkout` (bijv. warm-up, interval, rust, cooldown).
///
/// `targets` beschrijft de intentie (bijv. "houd vermogen rond 220W"), niet de
/// uitvoering. Hoe een adapter dat target vertaalt naar apparaatcommando's is
/// aan de adapter, niet aan CoachOS Connect zelf.
public struct WorkoutStep: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let kind: WorkoutStepKind
    public let duration: WorkoutDuration
    public let targets: [WorkoutTarget]

    public init(
        id: UUID = UUID(),
        name: String,
        kind: WorkoutStepKind,
        duration: WorkoutDuration,
        targets: [WorkoutTarget] = []
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.duration = duration
        self.targets = targets
    }
}

/// Eén onderdeel van de trainingsstructuur: hetzij een losse stap, hetzij
/// een groep stappen die als geheel wordt herhaald. Dit is wat "sport-
/// onafhankelijk bouwblokken" concreet betekent: een interval-training is
/// geen `RowInterval` of `CyclingInterval`, maar altijd dezelfde combinatie
/// van `WorkoutStep` en `RepeatGroup`, ongeacht de sport.
public enum WorkoutBlock: Codable, Equatable, Sendable {
    case step(WorkoutStep)
    case repeatGroup(RepeatGroup)
}

/// Een reeks stappen die als geheel `count` keer wordt uitgevoerd.
/// Bijvoorbeeld: 5× (4 min werk @ 220-240W, 2 min recovery).
public struct RepeatGroup: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let count: Int
    public let steps: [WorkoutStep]

    public init(id: UUID = UUID(), count: Int, steps: [WorkoutStep]) {
        self.id = id
        self.count = count
        self.steps = steps
    }
}

public enum WorkoutStepKind: String, Codable, Sendable {
    case warmup
    case work
    case interval
    case recovery
    case cooldown
    case rest
}

/// Duur van een stap: ofwel tijdgebaseerd, ofwel afstandgebaseerd.
/// Beide vormen komen voor (bijv. roeien op meters, hardlopen op tijd).
public enum WorkoutDuration: Codable, Equatable, Sendable {
    case time(seconds: Int)
    case distance(meters: Double)
    case openEnded
}

/// Eén stuurdoel binnen een stap. Een stap kan meerdere targets tegelijk hebben
/// (bijv. vermogen én cadans). De adapter bepaalt welke targets zijn apparaat
/// daadwerkelijk kan aansturen; niet-ondersteunde targets worden genegeerd,
/// nooit gesimuleerd.
public struct WorkoutTarget: Codable, Equatable, Sendable {
    public let metric: MetricType
    public let minValue: Double?
    public let maxValue: Double?

    public init(metric: MetricType, minValue: Double? = nil, maxValue: Double? = nil) {
        self.metric = metric
        self.minValue = minValue
        self.maxValue = maxValue
    }
}
