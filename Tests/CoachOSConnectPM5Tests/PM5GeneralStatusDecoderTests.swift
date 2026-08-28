import XCTest
@testable import CoachOSConnectPM5

final class PM5GeneralStatusDecoderTests: XCTestCase {

    /// Handmatig opgebouwde testvector, exact volgens de bevestigde
    /// 19-byte General Status-layout (officiële spec, Table 3,
    /// little-endian). Niet gevangen van echte hardware — dat gebeurt
    /// pas bij de eerste fysieke test (Sprint 7-onderzoeksrapport) — maar
    /// wel onafhankelijk met Python nagerekend vóór deze test geschreven
    /// werd.
    private let sampleBytes: [UInt8] = [
        57, 48, 0,      // elapsed: 12345 -> 123.45s
        133, 26, 0,     // distance: 6789 -> 678.9m
        6,               // workout type (fixedTimeInterval)
        0,               // interval type (time)
        4,               // workout state (intervalWorkTime)
        1,               // rowing state (active)
        2,               // stroke state (driving)
        244, 1, 0,       // total work distance: 500
        192, 93, 0,      // workout duration: 24000
        0,               // workout duration type (time)
        130              // drag factor
    ]

    func test_decode_validNineteenBytes_producesExpectedValues() throws {
        let status = try PM5GeneralStatusDecoder.decode(Data(sampleBytes))

        XCTAssertEqual(status.elapsedSeconds, 123.45, accuracy: 0.001)
        XCTAssertEqual(status.distanceMeters, 678.9, accuracy: 0.001)
        XCTAssertEqual(status.workoutTypeRaw, 6)
        XCTAssertEqual(status.intervalTypeRaw, 0)
        XCTAssertEqual(status.workoutState, .intervalWorkTime)
        XCTAssertEqual(status.workoutStateRaw, 4)
        XCTAssertEqual(status.rowingState, .active)
        XCTAssertEqual(status.strokeState, .driving)
        XCTAssertEqual(status.totalWorkDistanceRaw, 500)
        XCTAssertEqual(status.workoutDurationRaw, 24000)
        XCTAssertEqual(status.workoutDurationTypeRaw, 0)
        XCTAssertEqual(status.dragFactorRaw, 130)
    }

    func test_decode_wrongByteCount_throwsExplicitError_notPartialDecode() {
        let tooShort = Data(sampleBytes.dropLast(3)) // 16 bytes

        XCTAssertThrowsError(try PM5GeneralStatusDecoder.decode(tooShort)) { error in
            guard case PM5GeneralStatusDecodingError.unexpectedByteCount(let expected, let actual) = error else {
                return XCTFail("Verwachtte unexpectedByteCount, kreeg \(error)")
            }
            XCTAssertEqual(expected, 19)
            XCTAssertEqual(actual, 16)
        }
    }

    func test_decode_unknownWorkoutStateByte_doesNotCrash_returnsNilWithRawPreserved() throws {
        var bytes = sampleBytes
        bytes[8] = 200 // niet in de bevestigde 0-13-reeks
        let status = try PM5GeneralStatusDecoder.decode(Data(bytes))

        XCTAssertNil(status.workoutState)
        XCTAssertEqual(status.workoutStateRaw, 200)
    }

    func test_decode_zeroElapsedAndDistance_decodesToZero() throws {
        var bytes = sampleBytes
        bytes[0] = 0; bytes[1] = 0; bytes[2] = 0
        bytes[3] = 0; bytes[4] = 0; bytes[5] = 0
        let status = try PM5GeneralStatusDecoder.decode(Data(bytes))

        XCTAssertEqual(status.elapsedSeconds, 0)
        XCTAssertEqual(status.distanceMeters, 0)
    }
}
