import Foundation

/// Byte-stuffing zoals gedefinieerd in de officiële Concept2 CSAFE
/// Communication Definition (Table 6 – Byte Stuffing Values, bevestigd via
/// Revision 0.27, concept2.sg/files/pdf/us/monitors/PM5_CSAFECommunicationDefinition.pdf).
///
/// De vier bytes die een speciale betekenis hebben in een CSAFE-frame
/// (start, stop, stuffing-vlag zelf, en 0xF0) mogen niet ongewijzigd in de
/// frame-inhoud voorkomen. Ze worden vervangen door twee bytes: de
/// stuffing-vlag (0xF3) gevolgd door de oorspronkelijke waarde min 0xF0.
///
/// | Oorspronkelijke byte | Gestuft |
/// |---|---|
/// | 0xF0 | 0xF3, 0x00 |
/// | 0xF1 | 0xF3, 0x01 |
/// | 0xF2 | 0xF3, 0x02 |
/// | 0xF3 | 0xF3, 0x03 |
public enum CSAFEByteStuffing {
    public static let stuffFlag: UInt8 = 0xF3
    private static let stuffRangeStart: UInt8 = 0xF0

    public static func stuff(_ bytes: [UInt8]) -> [UInt8] {
        bytes.flatMap { byte -> [UInt8] in
            if byte >= stuffRangeStart {
                return [stuffFlag, byte - stuffRangeStart]
            }
            return [byte]
        }
    }

    /// - Throws: `CSAFEFrameError.invalidStuffing` als de stuffing-vlag
    ///   niet gevolgd wordt door een geldige waarde (0x00–0x03).
    public static func unstuff(_ bytes: [UInt8]) throws -> [UInt8] {
        var result: [UInt8] = []
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            if byte == stuffFlag {
                guard index + 1 < bytes.count else {
                    throw CSAFEFrameError.invalidStuffing
                }
                let offset = bytes[index + 1]
                guard offset <= 0x03 else {
                    throw CSAFEFrameError.invalidStuffing
                }
                result.append(stuffRangeStart + offset)
                index += 2
            } else {
                result.append(byte)
                index += 1
            }
        }
        return result
    }
}
