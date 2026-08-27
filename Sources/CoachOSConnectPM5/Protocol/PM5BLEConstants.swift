import Foundation

/// GATT-service- en characteristic-UUID's van de PM5, bevestigd via de
/// officiële "Concept2 PM Bluetooth Smart Communication Interface
/// Definition" (Revision 1.30, concept2.cn/files/pdf/us/monitors/
/// PM5_BluetoothSmartInterfaceDefinition.pdf).
///
/// Deze module wordt bewust nog NIET gekoppeld aan `CoachOSConnectBluetooth`
/// (geen BLE-verbinding in Sprint 5a) — dat is Sprint 5b. Deze constanten
/// staan hier alvast klaar, met bronvermelding, zodat ze straks niet
/// opnieuw uitgezocht hoeven te worden en niemand de verleiding voelt om
/// ze dan uit het geheugen te reconstrueren.
public enum PM5BLEConstants {
    /// Basis-UUID-patroon: `CE06XXXX-43E5-11E4-916C-0800200C9A66`.
    public static func uuid(_ shortID: String) -> String {
        "CE06\(shortID)-43E5-11E4-916C-0800200C9A66"
    }

    /// Device Discovery — gebruikt om de PM5 te herkennen tijdens scannen.
    public static let deviceDiscoveryServiceUUID = uuid("0000")

    /// Device Information Service (model/serienummer/firmware).
    public static let deviceInformationServiceUUID = uuid("0010")

    /// C2 PM Control Service — hierover lopen CSAFE-commando's en -responses.
    public static let controlServiceUUID = uuid("0020")

    /// C2 PM Receive Characteristic (WRITE) — CSAFE-frame naar de PM5.
    public static let controlReceiveCharacteristicUUID = uuid("0021")

    /// C2 PM Transmit Characteristic — CSAFE-frame VAN de PM5.
    ///
    /// Let op: de officiële tabel vermeldt permissie "READ", maar in de
    /// praktijk (bevestigd via meerdere forumdiscussies van ontwikkelaars
    /// die dit daadwerkelijk werkend hebben gekregen) moet hierop
    /// geabonneerd worden via notify/indicate om responses te ontvangen,
    /// niet gepolld via losse reads. Wordt in Sprint 5b als zodanig
    /// geïmplementeerd.
    public static let controlTransmitCharacteristicUUID = uuid("0022")

    /// C2 PM Rowing Service — live metrics-broadcast (niet gebruikt in
    /// Sprint 5a; relevant voor een latere live-metrics-sprint).
    public static let rowingServiceUUID = uuid("0030")
}
