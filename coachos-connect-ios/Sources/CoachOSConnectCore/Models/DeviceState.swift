import Foundation

/// Volledige levenscyclus van een apparaat binnen CoachOS Connect, van het
/// zoeken naar een apparaat tot en met het synchroniseren van een afgeronde
/// training. Elke `DeviceAdapterProtocol`-implementatie rapporteert zijn
/// actuele `DeviceState`; de UI-laag reageert daar rechtstreeks op zonder
/// zelf verbindings- of workout-logica te hoeven kennen.
///
/// De states zijn bewust generiek (geen "PM5Connecting" of "BluetoothScanning")
/// zodat elke toekomstige adapter — Bluetooth of anderszins — dezelfde
/// machine gebruikt.
public enum DeviceState: Equatable, Sendable {
    /// Geen actieve verbinding en niet aan het zoeken.
    case disconnected

    /// Actief op zoek naar dit apparaat (bijv. BLE-scan), nog geen verbinding.
    case scanning

    /// Verbinding wordt opgezet.
    case connecting

    /// Verbonden, geen workout geladen.
    case connected

    /// Verbonden én een `UniversalWorkout` is naar het apparaat gestuurd,
    /// nog niet gestart.
    case workoutLoaded

    /// Workout is actief bezig.
    case running

    /// Workout is onderbroken, kan hervat worden.
    case paused

    /// Workout is afgerond op het apparaat, nog niet gesynchroniseerd.
    case finished

    /// Trainingsdata wordt gesynchroniseerd (naar CoachOS en/of externe diensten).
    case syncing

    /// Onherstelbare fout in deze sessie. `message` is voor UI/diagnose,
    /// nooit voor sturingslogica — daarvoor bestaat `CoachOSConnectError`.
    case error(message: String)

    /// Gemakslabel voor UI-checks: is er in welke vorm dan ook een actieve
    /// verbinding met het apparaat.
    public var isConnected: Bool {
        switch self {
        case .connected, .workoutLoaded, .running, .paused, .finished, .syncing:
            return true
        case .disconnected, .scanning, .connecting, .error:
            return false
        }
    }
}

/// Toegestane overgangen tussen states. Adapters mogen hier gebruik van
/// maken om ongeldige transities (bijv. `.running` → `.workoutLoaded`)
/// vroeg te weigeren, in plaats van elke adapter dit zelf te laten
/// controleren.
public enum DeviceStateMachine {
    public static func canTransition(from current: DeviceState, to next: DeviceState) -> Bool {
        switch (current, next) {
        case (.disconnected, .scanning),
             (.disconnected, .connecting),
             (.scanning, .connecting),
             (.scanning, .disconnected),
             (.connecting, .connected),
             (.connecting, .disconnected),
             (.connecting, .error),
             (.connected, .workoutLoaded),
             (.connected, .disconnected),
             (.workoutLoaded, .running),
             (.workoutLoaded, .disconnected),
             (.running, .paused),
             (.running, .finished),
             (.running, .disconnected),
             (.running, .error),
             (.paused, .running),
             (.paused, .disconnected),
             (.paused, .error),
             (.finished, .syncing),
             (.finished, .disconnected),
             (.syncing, .disconnected),
             (.syncing, .error):
            return true
        case (_, .disconnected):
            // Vanuit elke state mag altijd hard losgekoppeld worden
            // (bijv. verbinding verloren, gebruiker annuleert).
            return true
        case (_, .error):
            // Elke state mag naar error, een fout kan altijd optreden.
            return true
        default:
            return false
        }
    }
}
