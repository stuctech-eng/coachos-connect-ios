import Foundation

/// Standaard (niet-proprietary) CSAFE-statuscommando's, bevestigd via drie
/// onafhankelijke bronnen die elkaar exact bevestigen: de officiële PM3-
/// documentatie (pcrower.sourceforge.net/pm3.pdf), tijmenvangulik's
/// PM3Monitor C-header, en het aparte c2api-project — plus daadwerkelijk
/// vastgelegd PM5-over-BLE-verkeer uit een Concept2-forumdiscussie.
///
/// Deze commando's zijn, anders dan de acht proprietary
/// `PM5ProprietaryCommand`-workoutcommando's, GEEN `detailCommand` onder een
/// wrapper — het zijn "short commands": één rauwe byte als volledige
/// frame-inhoud, geen lengte-byte, geen payload.
public enum PM5ControlCommand: UInt8, Sendable {
    case getStatus = 0x80
    case reset = 0x81
    case goIdle = 0x82
    case goHaveID = 0x83
    case goInUse = 0x85
    case goFinished = 0x86
    case goReady = 0x87

    /// Verzendklaar CSAFE-frame voor dit commando.
    public var frame: [UInt8] {
        CSAFEFrame.encode(content: [rawValue])
    }
}
