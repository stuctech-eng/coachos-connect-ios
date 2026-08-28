import Foundation

/// Bevestigd (officiële spec, Appendix A, `OBJ_WORKOUTSTATE_T`).
public enum PM5WorkoutState: UInt8, Sendable {
    case waitToBegin = 0
    case workoutRow = 1
    case countdownPause = 2
    case intervalRest = 3
    case intervalWorkTime = 4
    case intervalWorkDistance = 5
    case intervalRestEndToWorkTime = 6
    case intervalRestEndToWorkDistance = 7
    case intervalWorkTimeToRest = 8
    case intervalWorkDistanceToRest = 9
    case workoutEnd = 10
    case terminate = 11
    case workoutLogged = 12
    case rearm = 13
}

/// Bevestigd (`OBJ_ROWINGSTATE_T`).
public enum PM5RowingState: UInt8, Sendable {
    case inactive = 0
    case active = 1
}

/// Bevestigd (`OBJ_STROKESTATE_T`).
public enum PM5StrokeState: UInt8, Sendable {
    case waitingForWheelToReachMinSpeed = 0
    case waitingForWheelToAccelerate = 1
    case driving = 2
    case dwellingAfterDrive = 3
    case recovery = 4
}

/// Gedecodeerde inhoud van characteristic `0x0031` (General Status, 19
/// bytes, bevestigd via de officiële spec, Table 3).
///
/// Velden waarvan de eenheid NIET expliciet bevestigd is voor dit
/// specifieke veld (anders dan `elapsedSeconds`/`distanceMeters`, die wél
/// expliciet "0.01 sec lsb"/"0.1 m lsb" vermeld staan) blijven bewust
/// rauw — geen gegokte schaling. Zie het Sprint 7-onderzoeksrapport.
///
/// `workoutState`/`rowingState`/`strokeState` zijn optioneel: een
/// onbekende byte-waarde (bijv. door een firmwareversie met extra
/// states) crasht niet, maar geeft `nil` — de rauwe waarde blijft altijd
/// beschikbaar via de `*Raw`-velden.
public struct PM5GeneralStatus: Equatable, Sendable {
    public let elapsedSeconds: Double
    public let distanceMeters: Double

    public let workoutTypeRaw: UInt8
    public let intervalTypeRaw: UInt8

    public let workoutState: PM5WorkoutState?
    public let workoutStateRaw: UInt8
    public let rowingState: PM5RowingState?
    public let rowingStateRaw: UInt8
    public let strokeState: PM5StrokeState?
    public let strokeStateRaw: UInt8

    /// Eenheid niet expliciet bevestigd voor dit veld — bewust rauw.
    public let totalWorkDistanceRaw: UInt32
    /// Bevestigd 0.01s wanneer `workoutDurationTypeRaw` tijd aangeeft;
    /// bij andere duurtypen niet expliciet bevestigd — bewust rauw.
    public let workoutDurationRaw: UInt32
    public let workoutDurationTypeRaw: UInt8
    public let dragFactorRaw: UInt8

    public init(
        elapsedSeconds: Double,
        distanceMeters: Double,
        workoutTypeRaw: UInt8,
        intervalTypeRaw: UInt8,
        workoutState: PM5WorkoutState?,
        workoutStateRaw: UInt8,
        rowingState: PM5RowingState?,
        rowingStateRaw: UInt8,
        strokeState: PM5StrokeState?,
        strokeStateRaw: UInt8,
        totalWorkDistanceRaw: UInt32,
        workoutDurationRaw: UInt32,
        workoutDurationTypeRaw: UInt8,
        dragFactorRaw: UInt8
    ) {
        self.elapsedSeconds = elapsedSeconds
        self.distanceMeters = distanceMeters
        self.workoutTypeRaw = workoutTypeRaw
        self.intervalTypeRaw = intervalTypeRaw
        self.workoutState = workoutState
        self.workoutStateRaw = workoutStateRaw
        self.rowingState = rowingState
        self.rowingStateRaw = rowingStateRaw
        self.strokeState = strokeState
        self.strokeStateRaw = strokeStateRaw
        self.totalWorkDistanceRaw = totalWorkDistanceRaw
        self.workoutDurationRaw = workoutDurationRaw
        self.workoutDurationTypeRaw = workoutDurationTypeRaw
        self.dragFactorRaw = dragFactorRaw
    }
}
