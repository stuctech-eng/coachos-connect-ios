import Foundation

/// De universele interface voor BLE-communicatie. Dit is de enige manier
/// waarop de rest van de app (uiteindelijk: adapters zoals `PM5Adapter` in
/// Sprint 5) met Bluetooth praat.
///
/// Kent geen fabrikanten, geen service-/characteristic-UUID's van specifieke
/// apparaten, geen protocolsemantiek (CSAFE of anders). Alleen generieke
/// BLE-primitieven: scannen, verbinden, services/characteristics ontdekken,
/// lezen, schrijven, abonneren.
///
/// Volledig `async throws`/`AsyncStream`-gebaseerd en protocol-based, zodat
/// hogere lagen (toekomstige adapters) hiertegen getest kunnen worden met
/// een mock (zie `Testing/MockBluetoothManager.swift`), zonder echte
/// hardware of een fysiek iPhone nodig te hebben.
public protocol BluetoothManagerProtocol: Sendable {

    // MARK: Scannen & ontdekking

    /// Start scannen naar apparaten. `serviceUUIDs` filtert op geadverteerde
    /// services; `nil` betekent: alle zichtbare BLE-apparaten. Filteren op
    /// specifieke UUID's (bijv. de PM5-service) is de verantwoordelijkheid
    /// van de aanroepende adapter, niet van deze laag.
    func startScan(matching serviceUUIDs: [String]?) async throws

    func stopScan() async

    /// Stream van ontdekte apparaten zolang er gescand wordt. Kan dubbele
    /// entries voor hetzelfde apparaat bevatten (bijv. bij een sterkere
    /// signaalmeting); de ontvangende laag dedupliceert op `id` indien nodig.
    func discoveredDevicesStream() -> AsyncStream<BluetoothDevice>

    // MARK: Verbinding

    func connect(to deviceId: UUID) async throws
    func disconnect(from deviceId: UUID) async throws

    func connectionState(for deviceId: UUID) async -> BluetoothConnectionState

    /// Stream van verbindingsstatuswijzigingen voor één specifiek apparaat.
    func connectionStateStream(for deviceId: UUID) -> AsyncStream<BluetoothConnectionState>

    /// Bepaalt of, en hoe vaak, automatisch herverbonden wordt bij
    /// onverwacht verbindingsverlies. Standaard (indien nooit aangeroepen):
    /// `.manual`.
    func setReconnectPolicy(_ policy: BluetoothReconnectPolicy, for deviceId: UUID) async

    // MARK: Services & characteristics

    /// Ontdekt services en characteristics van een verbonden apparaat.
    /// `serviceUUIDs` filtert, `nil` ontdekt alles wat het apparaat
    /// adverteert.
    func discoverServicesAndCharacteristics(for deviceId: UUID, serviceUUIDs: [String]?) async throws -> [BLEService]

    // MARK: Lezen, schrijven, abonneren

    func write(_ data: Data, to characteristic: BLECharacteristicAddress, on deviceId: UUID, expectingResponse: Bool) async throws

    func read(_ characteristic: BLECharacteristicAddress, on deviceId: UUID) async throws -> Data

    /// Abonneert op notify/indicate-updates van een characteristic. De
    /// stream loopt door totdat `unsubscribe` wordt aangeroepen of de
    /// verbinding wegvalt (in dat laatste geval sluit de stream af).
    func subscribe(to characteristic: BLECharacteristicAddress, on deviceId: UUID) async throws -> AsyncStream<Data>

    func unsubscribe(from characteristic: BLECharacteristicAddress, on deviceId: UUID) async throws
}
