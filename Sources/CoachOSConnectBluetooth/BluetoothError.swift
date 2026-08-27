import Foundation

/// Foutdomein van de generieke Bluetooth-laag. Kent geen fabrikanten of
/// protocollen (geen PM5, geen CSAFE) — alleen transportfouten die voor
/// elk BLE-apparaat kunnen optreden.
public enum BluetoothError: Error, Equatable, Sendable {
    case bluetoothUnavailable
    case bluetoothUnauthorized
    case scanFailed(reason: String)
    case deviceNotFound(id: UUID)
    case connectionFailed(reason: String)
    case connectionTimedOut
    case notConnected
    case serviceNotFound(uuid: String)
    case characteristicNotFound(uuid: String)
    case writeFailed(reason: String)
    case readFailed(reason: String)
    case subscriptionFailed(reason: String)
    case unknown(reason: String)
}

extension BluetoothError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable:
            return "Bluetooth is niet beschikbaar op dit toestel."
        case .bluetoothUnauthorized:
            return "Geen toestemming voor Bluetooth."
        case .scanFailed(let reason):
            return "Scannen mislukt: \(reason)."
        case .deviceNotFound(let id):
            return "Apparaat niet gevonden: \(id)."
        case .connectionFailed(let reason):
            return "Verbinden mislukt: \(reason)."
        case .connectionTimedOut:
            return "Verbinding verlopen (timeout)."
        case .notConnected:
            return "Geen actieve verbinding met dit apparaat."
        case .serviceNotFound(let uuid):
            return "Service niet gevonden: \(uuid)."
        case .characteristicNotFound(let uuid):
            return "Characteristic niet gevonden: \(uuid)."
        case .writeFailed(let reason):
            return "Schrijven mislukt: \(reason)."
        case .readFailed(let reason):
            return "Lezen mislukt: \(reason)."
        case .subscriptionFailed(let reason):
            return "Abonneren op notificaties mislukt: \(reason)."
        case .unknown(let reason):
            return "Onbekende Bluetooth-fout: \(reason)."
        }
    }
}
