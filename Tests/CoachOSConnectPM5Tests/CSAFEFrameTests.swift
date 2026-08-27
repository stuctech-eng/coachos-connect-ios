import XCTest
@testable import CoachOSConnectPM5

/// Deze tests gebruiken UITSLUITEND echte, in het wild vastgelegde
/// CSAFE-frames uit ontwikkelaarsdiscussies (Concept2-forum), niet
/// zelfverzonnen voorbeelden. Als deze tests slagen, is de framing-,
/// stuffing- en checksumlogica geverifieerd tegen daadwerkelijk door een
/// PM5 geaccepteerde/verzonden bytes — niet alleen intern consistent.
final class CSAFEFrameTests: XCTestCase {

    /// CSAFE_GETSERIAL_CMD (0x94): request en response, zoals gepost op
    /// het Concept2-forum ("CSAFE + BLE Characteristic"-topic).
    func test_encode_getSerialRequest_matchesRealCapturedFrame() {
        let frame = CSAFEFrame.encode(content: [0x94])
        XCTAssertEqual(frame, [0xF1, 0x94, 0x94, 0xF2])
    }

    func test_decode_getSerialResponse_matchesRealCapturedFrame() throws {
        // Response: status 0x81, echo van commando 0x94, lengte 0x09,
        // ASCII "430109199" als serienummer, checksum 0x22.
        let captured: [UInt8] = [0xF1, 0x81, 0x94, 0x09, 0x34, 0x33, 0x30, 0x31, 0x30, 0x39, 0x31, 0x39, 0x39, 0x22, 0xF2]
        let content = try CSAFEFrame.decode(captured)
        XCTAssertEqual(content, [0x81, 0x94, 0x09, 0x34, 0x33, 0x30, 0x31, 0x30, 0x39, 0x31, 0x39, 0x39])
    }

    /// CSAFE_SETTWORK_CMD (0x20), werktijd-doel 7:30 — tweede, onafhankelijke
    /// verificatie van dezelfde checksum-formule met een ander commando.
    func test_encode_setWorkTimeExample_matchesRealCapturedFrame() {
        let frame = CSAFEFrame.encode(content: [0x20, 0x03, 0x00, 0x07, 0x1E])
        XCTAssertEqual(frame, [0xF1, 0x20, 0x03, 0x00, 0x07, 0x1E, 0x3A, 0xF2])
    }

    // MARK: - Round-trip en foutafhandeling

    func test_encodeDecode_roundTrip() throws {
        let content: [UInt8] = [0x76, 0x02, 0x01, 0x08]
        let frame = CSAFEFrame.encode(content: content)
        let decoded = try CSAFEFrame.decode(frame)
        XCTAssertEqual(decoded, content)
    }

    func test_encode_stuffsBytesInReservedRange() {
        // 0xF1 als inhoudsbyte moet gestuft worden naar [0xF3, 0x01].
        let frame = CSAFEFrame.encode(content: [0xF1])
        XCTAssertEqual(frame, [0xF1, 0xF3, 0x01, 0xF3, 0x01, 0xF2])
    }

    func test_decode_unstuffsBytesCorrectly() throws {
        let frame = CSAFEFrame.encode(content: [0xF0, 0xF1, 0xF2, 0xF3])
        let decoded = try CSAFEFrame.decode(frame)
        XCTAssertEqual(decoded, [0xF0, 0xF1, 0xF2, 0xF3])
    }

    func test_decode_missingStartByte_throws() {
        XCTAssertThrowsError(try CSAFEFrame.decode([0x00, 0x94, 0xF2])) { error in
            XCTAssertEqual(error as? CSAFEFrameError, .missingStartByte)
        }
    }

    func test_decode_checksumMismatch_throws() {
        // Correcte frame zou [0xF1, 0x94, 0x94, 0xF2] zijn; checksum hier
        // opzettelijk fout.
        XCTAssertThrowsError(try CSAFEFrame.decode([0xF1, 0x94, 0x00, 0xF2])) { error in
            guard case CSAFEFrameError.checksumMismatch(let expected, let actual) = error else {
                return XCTFail("Verwachtte checksumMismatch, kreeg \(error)")
            }
            XCTAssertEqual(expected, 0x94)
            XCTAssertEqual(actual, 0x00)
        }
    }
}
