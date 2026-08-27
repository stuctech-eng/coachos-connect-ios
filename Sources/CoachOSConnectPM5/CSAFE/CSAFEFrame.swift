import Foundation

public enum CSAFEFrameError: Error, Equatable, Sendable {
    case invalidStuffing
    case missingStartByte
    case missingStopByte
    case frameTooShort
    case checksumMismatch(expected: UInt8, actual: UInt8)
}

/// Encoding/decoding van een CSAFE-frame op byteniveau: start-byte, stop-byte,
/// byte-stuffing en XOR-checksum. Kent geen enkel PM5-commando — dat is de
/// verantwoordelijkheid van `PM5ProprietaryCommand`. Deze laag is puur
/// transport-framing, en is 1-op-1 geverifieerd tegen twee daadwerkelijk
/// vastgelegde CSAFE-frames uit Concept2-forumdiscussies:
///
/// 1. `CSAFE_GETSERIAL_CMD` (0x94), request/response — bevat geen
///    te-stuffen bytes, dient als eenvoudige checksum-verificatie.
/// 2. `CSAFE_SETTWORK_CMD` (0x20) met payload `[0x00, 0x07, 0x1E]` —
///    onafhankelijke tweede verificatie van dezelfde checksum-formule.
///
/// Beide voorbeelden staan letterlijk terug als testfixtures in
/// `CSAFEFrameTests`.
public enum CSAFEFrame {
    public static let startByte: UInt8 = 0xF1
    public static let stopByte: UInt8 = 0xF2

    /// Bouwt een compleet, verzendklaar frame van de gegeven (ongestufte)
    /// inhoud: start-byte, gestufte inhoud, gestufte checksum, stop-byte.
    /// De checksum wordt berekend over de ONgestufte inhoud (zoals
    /// voorgeschreven door de officiële CSAFE-spec: "checksum is computed
    /// ... after byte-unstuffing"), maar de checksum-byte zelf wordt, net
    /// als de rest van de inhoud, wél gestuft bij het plaatsen in de
    /// bytestroom.
    public static func encode(content: [UInt8]) -> [UInt8] {
        let checksum = content.reduce(0) { $0 ^ $1 }
        let stuffedContent = CSAFEByteStuffing.stuff(content)
        let stuffedChecksum = CSAFEByteStuffing.stuff([checksum])
        return [startByte] + stuffedContent + stuffedChecksum + [stopByte]
    }

    /// Ontleedt een ontvangen frame en geeft de ongestufte, geverifieerde
    /// inhoud terug (zonder start/stop/checksum).
    public static func decode(_ frame: [UInt8]) throws -> [UInt8] {
        guard let first = frame.first, first == startByte else {
            throw CSAFEFrameError.missingStartByte
        }
        guard let last = frame.last, last == stopByte else {
            throw CSAFEFrameError.missingStopByte
        }
        guard frame.count >= 3 else {
            throw CSAFEFrameError.frameTooShort
        }

        let inner = Array(frame.dropFirst().dropLast())
        let unstuffed = try CSAFEByteStuffing.unstuff(inner)

        guard let receivedChecksum = unstuffed.last else {
            throw CSAFEFrameError.frameTooShort
        }
        let content = Array(unstuffed.dropLast())
        let computedChecksum = content.reduce(0) { $0 ^ $1 }

        guard computedChecksum == receivedChecksum else {
            throw CSAFEFrameError.checksumMismatch(expected: computedChecksum, actual: receivedChecksum)
        }

        return content
    }
}
