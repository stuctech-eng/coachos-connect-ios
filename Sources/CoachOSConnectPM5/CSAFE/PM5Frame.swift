import Foundation

/// Verpakt één of meer `PM5ProprietaryCommand`'s in een compleet,
/// verzendklaar CSAFE-frame, via de bevestigde `SETPMCFG_CMD`-wrapper.
///
/// Frame-inhoud per commando-blok (bevestigd "long command"-formaat,
/// zoals ook gebruikt door het niet-proprietary `CSAFE_SETTWORK_CMD`-
/// voorbeeld dat als testfixture dient):
///
/// `[0x76 (SETPMCFG_CMD)] [lengte] [detailCommand] [payload...]`
///
/// waarbij `lengte` = 1 (detailCommand-byte) + het aantal payload-bytes.
///
/// Meerdere commando's kunnen als losse blokken ná elkaar in dezelfde
/// frame-inhoud staan (zo werkt CSAFE in het algemeen: meerdere
/// commando-blokken, één checksum over het geheel). Of dat in de praktijk
/// verstandig is gezien de kleine BLE-pakketgrootte (bevestigd: max 20
/// bytes bruikbare data per pakket, zie officiële Bluetooth-spec) is een
/// vraag voor de transportlaag (Sprint 5b), niet voor deze encoder — deze
/// geeft alleen correct gevormde bytes terug, ongeacht hoe ze vervolgens
/// over de lucht in stukken worden geknipt.
public enum PM5Frame {
    private static let setPMConfigCommandID: UInt8 = 0x76

    /// Bouwt de frame-inhoud (nog vóór CSAFE-framing/checksum/stuffing)
    /// voor één `SETPMCFG_CMD`-blok met de gegeven commando's.
    public static func content(for commands: [PM5ProprietaryCommand]) -> [UInt8] {
        commands.flatMap { command -> [UInt8] in
            let detailPayload = [command.detailCommandID] + command.payload
            return [setPMConfigCommandID, UInt8(detailPayload.count)] + detailPayload
        }
    }

    /// Bouwt het volledige, verzendklare CSAFE-frame voor de gegeven
    /// commando's (start-byte, stuffing, checksum, stop-byte).
    public static func encode(_ commands: [PM5ProprietaryCommand]) -> [UInt8] {
        CSAFEFrame.encode(content: content(for: commands))
    }

    public static func encode(_ command: PM5ProprietaryCommand) -> [UInt8] {
        encode([command])
    }
}
