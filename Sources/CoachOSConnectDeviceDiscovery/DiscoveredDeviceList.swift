import Foundation
import CoachOSConnectBluetooth

/// Pure, side-effect-vrije logica voor het bijhouden van een lijst
/// ontdekte apparaten tijdens een scan. Losstaand van Combine/SwiftUI en
/// van de `BluetoothManagerProtocol`-stream zelf, zodat dit zonder async
/// en zonder mock rechtstreeks getest kan worden.
///
/// Regels (generiek, geen fabrikantkennis):
/// - Eén apparaat verschijnt maximaal één keer in de lijst (dedupliceren op `id`).
/// - Bij herontdekking wordt de meest recente meting gebruikt (RSSI kan wisselen).
/// - Gesorteerd op signaalsterkte (sterkste eerst) — een generiek, voor elk
///   BLE-apparaat zinvol UX-criterium, geen apparaatspecifieke logica.
public enum DiscoveredDeviceList {
    public static func merging(_ device: BluetoothDevice, into devices: [BluetoothDevice]) -> [BluetoothDevice] {
        var result = devices.filter { $0.id != device.id }
        result.append(device)
        return result.sorted { $0.rssi > $1.rssi }
    }

    public static func cleared() -> [BluetoothDevice] {
        []
    }
}
