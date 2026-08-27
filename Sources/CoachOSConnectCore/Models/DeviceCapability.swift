import Foundation

/// Eén vaardigheid die een apparaat wel of niet ondersteunt.
///
/// Het capability-systeem is de kern van de hardware-onafhankelijkheid:
/// CoachOS Connect vraagt nooit "is dit een PM5?" maar altijd
/// "ondersteunt dit apparaat `.power`?" of "ondersteunt dit apparaat
/// `.ergMode`?". Nieuwe apparaten toevoegen betekent nooit het aanpassen
/// van bestaande aanroepcode, alleen het invullen van `capabilities()`
/// in de nieuwe adapter.
public enum DeviceCapability: String, Codable, Sendable, CaseIterable {
    // Metrieken die een apparaat kan leveren
    case heartRate
    case power
    case cadence
    case strokeRate
    case speed
    case distance
    case pace
    case elevation

    // Sturingsmogelijkheden
    case ergMode          // apparaat kan een vermogensdoel afdwingen (smart trainer)
    case resistanceControl
    case pausable
    case resumable

    // Connectiviteit
    case backgroundStreaming
    case offlineBuffering
    case batteryReporting
}

/// Statische identificatie van een apparaattype, onafhankelijk van een
/// actieve verbinding. Wordt gebruikt door de `DeviceAdapterRegistry` om
/// te bepalen welke adapter in aanmerking komt voor een gevonden apparaat.
public struct DeviceDescriptor: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let manufacturer: String
    public let model: String
    public let capabilities: Set<DeviceCapability>

    public init(id: String, manufacturer: String, model: String, capabilities: Set<DeviceCapability>) {
        self.id = id
        self.manufacturer = manufacturer
        self.model = model
        self.capabilities = capabilities
    }
}
