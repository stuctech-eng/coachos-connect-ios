import Foundation

/// De acht bevestigde PM5-workoutprogrammeer-commando's, exact zoals
/// vastgelegd in het onderzoek (ErgometerJS, PM3Monitor, officiële
/// Concept2-documentatie). Elke case draagt zijn eigen, reeds
/// gevalideerde eenheid — de aanroeper hoeft geen ×100 of MSB-volgorde
/// zelf te onthouden.
///
/// BELANGRIJK — herkomst van de wrapper: deze commando's zijn geen
/// top-level CSAFE-commando's. Ze zijn `detailCommand`-waarden onder het
/// proprietary "long" wrapper-commando `SETPMCFG_CMD = 0x76`, bevestigd in
/// twee onafhankelijke bronnen van dezelfde auteur (ErgometerJS
/// `command_core.ts`: `LONG_PMPROPRIETARY_CMDS.SETPMCFG_CMD`, en het
/// aparte PM3Monitor-C++-project: `CSAFE_SETPMCFG_CMD = 0x76`). Zie
/// `PM5Frame.wrapping(_:)`.
public enum PM5ProprietaryCommand: Equatable, Sendable {
    /// 0x01 — 1 byte enum. Zie `PM5WorkoutType`.
    case setWorkoutType(UInt8)

    /// 0x03 — 1 byte duration-type + 4 byte waarde (MSB eerst).
    /// Tijd: waarde × 100 (0.01s-eenheden). Afstand: rauwe meters.
    /// `durationType` volgt de bevestigde enum: 0x00 = tijd, 0x80 = afstand.
    case setWorkoutDuration(durationType: UInt8, value: UInt32)

    /// 0x04 — 2 bytes (MSB eerst), rauwe seconden.
    case setRestDuration(seconds: UInt16)

    /// 0x06 — 4 bytes (MSB eerst), geen type-byte. Eenheid: 0.01 seconde
    /// (dus seconden × 100). Voorbeeld uit ErgometerJS: 1:40 → 10000.
    case setTargetPaceTime(centiseconds: UInt32)

    /// 0x14 — 1 byte: 1 = programmingMode aan, 0 = uit. Het bevestigde
    /// werkende patroon gebruikt uitsluitend `true` per configuratieblok;
    /// `false` heeft geen bevestigde, noodzakelijke betekenis (zie
    /// projectcontext) en wordt hier daarom niet als apart geval
    /// aangeboden om er geen verkeerd gebruik van te suggereren.
    case configureWorkout(programmingMode: Bool)

    /// 0x15 — 2 bytes (MSB eerst), rauwe watts, geen eenheid-byte.
    /// Gebruik dit, niet het generieke publieke `CSAFE_SETPOWER_CMD`
    /// (0x34) — dat heeft een andere payload-structuur en is niet het
    /// bevestigde commando voor deze programmeersequentie.
    case setTargetAverageWatts(UInt16)

    /// 0x17 — 1 byte enum. Zie `PM5IntervalType`.
    case setIntervalType(UInt8)

    /// 0x18 — 1 byte, 0-based interval-index. Interval 1 = waarde 0,
    /// interval 2 = waarde 1, enzovoort.
    case setWorkoutIntervalCount(UInt8)

    /// De `detailCommand`-byte-waarde van dit commando.
    public var detailCommandID: UInt8 {
        switch self {
        case .setWorkoutType: return 0x01
        case .setWorkoutDuration: return 0x03
        case .setRestDuration: return 0x04
        case .setTargetPaceTime: return 0x06
        case .configureWorkout: return 0x14
        case .setTargetAverageWatts: return 0x15
        case .setIntervalType: return 0x17
        case .setWorkoutIntervalCount: return 0x18
        }
    }

    /// De payload-bytes van dit commando, ZONDER de `detailCommand`-byte
    /// zelf. Big-endian (MSB eerst) waar van toepassing, zoals bevestigd.
    public var payload: [UInt8] {
        switch self {
        case .setWorkoutType(let value):
            return [value]

        case .setWorkoutDuration(let durationType, let value):
            return [durationType] + value.bigEndianBytes

        case .setRestDuration(let seconds):
            return seconds.bigEndianBytes

        case .setTargetPaceTime(let centiseconds):
            return centiseconds.bigEndianBytes

        case .configureWorkout(let programmingMode):
            return [programmingMode ? 0x01 : 0x00]

        case .setTargetAverageWatts(let watts):
            return watts.bigEndianBytes

        case .setIntervalType(let value):
            return [value]

        case .setWorkoutIntervalCount(let index):
            return [index]
        }
    }
}

/// Bevestigde `WorkoutDurationType`-waarden (officiële Concept2 BLE-spec,
/// Appendix A: `enum DurationTypes`).
public enum PM5DurationType {
    public static let time: UInt8 = 0x00
    public static let calories: UInt8 = 0x40
    public static let distance: UInt8 = 0x80
    public static let watts: UInt8 = 0xC0
}

/// Bevestigde `WorkoutType`-waarden (officiële Concept2 BLE-spec,
/// Appendix A: `OBJ_WORKOUTTYPE_T`).
public enum PM5WorkoutType {
    public static let justRowNoSplits: UInt8 = 0
    public static let justRowSplits: UInt8 = 1
    public static let fixedDistNoSplits: UInt8 = 2
    public static let fixedDistSplits: UInt8 = 3
    public static let fixedTimeNoSplits: UInt8 = 4
    public static let fixedTimeSplits: UInt8 = 5
    public static let fixedTimeInterval: UInt8 = 6
    public static let fixedDistInterval: UInt8 = 7
    public static let variableInterval: UInt8 = 8
    public static let variableUndefinedRestInterval: UInt8 = 9
    public static let fixedCalorie: UInt8 = 10
    public static let fixedWattMinutes: UInt8 = 11
    public static let fixedCalsInterval: UInt8 = 12
}

/// Bevestigde `IntervalType`-waarden (officiële Concept2 BLE-spec,
/// Appendix A: `OBJ_INTERVALTYPE_T`). Dit lost een deel van de eerder
/// openstaande onderzoeksvraag op: de enum-namen én -waarden voor de
/// undefined-rest-varianten zijn nu officieel bevestigd. Wat nog steeds
/// ontbreekt is een gevalideerd, werkend voorbeeld van de volledige
/// programmeersequentie voor die varianten — vandaar dat
/// `PM5WorkoutProgrammer` ze nog steeds expliciet weigert (zie aldaar).
public enum PM5IntervalType {
    public static let time: UInt8 = 0
    public static let distance: UInt8 = 1
    public static let rest: UInt8 = 2
    public static let timeRestUndefined: UInt8 = 3
    public static let distanceRestUndefined: UInt8 = 4
    public static let restUndefined: UInt8 = 5
    public static let calorie: UInt8 = 6
    public static let calorieRestUndefined: UInt8 = 7
    public static let wattMinute: UInt8 = 8
    public static let wattMinuteRestUndefined: UInt8 = 9
    public static let none: UInt8 = 255
}

extension UInt32 {
    /// Big-endian (MSB eerst) 4-byte representatie, zoals bevestigd voor
    /// alle multi-byte PM5-programmeerwaarden.
    var bigEndianBytes: [UInt8] {
        [UInt8((self >> 24) & 0xFF), UInt8((self >> 16) & 0xFF), UInt8((self >> 8) & 0xFF), UInt8(self & 0xFF)]
    }
}

extension UInt16 {
    var bigEndianBytes: [UInt8] {
        [UInt8((self >> 8) & 0xFF), UInt8(self & 0xFF)]
    }
}
