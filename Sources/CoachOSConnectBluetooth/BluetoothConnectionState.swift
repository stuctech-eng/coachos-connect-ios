import Foundation

/// Verbindingsstatus op transportniveau, voor één specifiek BLE-apparaat.
///
/// Bewust kleiner en generieker dan `DeviceState` (in `CoachOSConnectCore`):
/// dat model beschrijft de volledige workout-levenscyclus van een
/// `DeviceAdapter` (inclusief `workoutLoaded`, `running`, `syncing`, ...).
/// Dit model beschrijft uitsluitend de BLE-verbinding zelf, zonder ook maar
/// iets te weten over workouts, CSAFE of PM5. Een toekomstige `PM5Adapter`
/// bouwt zijn `DeviceState` deels op basis van wat hij hier ziet, maar de
/// twee state machines blijven gescheiden — dat is de scheiding uit
/// sectie 31/33 van het masterdocument.
public enum BluetoothConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case disconnecting
    case failed(reason: String)
}

/// Toegestane overgangen tussen BLE-verbindingsstates. Zelfde patroon als
/// `DeviceStateMachine` in Core, maar losstaand — deze twee machines mogen
/// nooit met elkaar vermengd worden.
public enum BluetoothStateMachine {
    public static func canTransition(from current: BluetoothConnectionState, to next: BluetoothConnectionState) -> Bool {
        switch (current, next) {
        case (.disconnected, .connecting),
             (.connecting, .connected),
             (.connecting, .disconnected),
             (.connecting, .failed),
             (.connected, .disconnecting),
             (.connected, .reconnecting),
             (.connected, .disconnected),
             (.connected, .failed),
             (.reconnecting, .connected),
             (.reconnecting, .disconnected),
             (.reconnecting, .failed),
             (.disconnecting, .disconnected),
             (.disconnecting, .failed):
            return true
        case (_, .disconnected):
            // Verbinding kan altijd hard verbroken worden (bv. Bluetooth
            // uitgeschakeld, gebruiker annuleert).
            return true
        case (_, .failed):
            return true
        default:
            return false
        }
    }
}
