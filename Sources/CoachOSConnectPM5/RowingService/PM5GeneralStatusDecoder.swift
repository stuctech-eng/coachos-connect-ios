import Foundation

public enum PM5GeneralStatusDecodingError: Error, Equatable, Sendable {
    case unexpectedByteCount(expected: Int, actual: Int)
}

extension PM5GeneralStatusDecodingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unexpectedByteCount(let expected, let actual):
            return "0x0031 General Status: verwachtte \(expected) bytes, kreeg \(actual)."
        }
    }
}

/// Decodeert characteristic `0x0031` (General Status). Bevestigd via de
/// officiële Concept2 BLE-interfacedefinitie (Rev 1.30, Table 3).
///
/// Byte-volgorde: LITTLE-ENDIAN ("Lo" eerst) — dit is een BEWUSTE,
/// andere conventie dan de CSAFE-proprietary-commando's op de Control
/// Service, die MSB-eerst (big-endian) zijn (zie `PM5ProprietaryCommand`,
/// Sprint 5a). Twee verschillende services, twee verschillende, elk apart
/// bevestigde byte-volgordes — niet met elkaar verward.
///
/// Gooit expliciet bij een onverwachte bytelengte. GEEN best-effort
/// gedeeltelijke decodering: een verkeerde offset bij dit protocol
/// levert ogenschijnlijk geldige maar foute waarden op (bijv. een
/// hartslag die eigenlijk een stukje afstand is) — gevaarlijker dan een
/// crash. Zie het Sprint 7-onderzoeksrapport.
public enum PM5GeneralStatusDecoder {
    public static let expectedByteCount = 19

    public static func decode(_ data: Data) throws -> PM5GeneralStatus {
        let bytes = [UInt8](data)
        guard bytes.count == expectedByteCount else {
            throw PM5GeneralStatusDecodingError.unexpectedByteCount(expected: expectedByteCount, actual: bytes.count)
        }

        let elapsedRaw = threeByteLittleEndian(bytes[0], bytes[1], bytes[2])
        let distanceRaw = threeByteLittleEndian(bytes[3], bytes[4], bytes[5])
        let workoutTypeRaw = bytes[6]
        let intervalTypeRaw = bytes[7]
        let workoutStateRaw = bytes[8]
        let rowingStateRaw = bytes[9]
        let strokeStateRaw = bytes[10]
        let totalWorkDistanceRaw = threeByteLittleEndian(bytes[11], bytes[12], bytes[13])
        let workoutDurationRaw = threeByteLittleEndian(bytes[14], bytes[15], bytes[16])
        let workoutDurationTypeRaw = bytes[17]
        let dragFactorRaw = bytes[18]

        return PM5GeneralStatus(
            elapsedSeconds: Double(elapsedRaw) / 100.0,
            distanceMeters: Double(distanceRaw) / 10.0,
            workoutTypeRaw: workoutTypeRaw,
            intervalTypeRaw: intervalTypeRaw,
            workoutState: PM5WorkoutState(rawValue: workoutStateRaw),
            workoutStateRaw: workoutStateRaw,
            rowingState: PM5RowingState(rawValue: rowingStateRaw),
            rowingStateRaw: rowingStateRaw,
            strokeState: PM5StrokeState(rawValue: strokeStateRaw),
            strokeStateRaw: strokeStateRaw,
            totalWorkDistanceRaw: totalWorkDistanceRaw,
            workoutDurationRaw: workoutDurationRaw,
            workoutDurationTypeRaw: workoutDurationTypeRaw,
            dragFactorRaw: dragFactorRaw
        )
    }

    private static func threeByteLittleEndian(_ lo: UInt8, _ mid: UInt8, _ hi: UInt8) -> UInt32 {
        UInt32(lo) | (UInt32(mid) << 8) | (UInt32(hi) << 16)
    }
}
