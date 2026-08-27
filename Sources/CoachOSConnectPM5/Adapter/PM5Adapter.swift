import Foundation
import CoachOSConnectCore
import CoachOSConnectBluetooth

/// Concrete `DeviceAdapterProtocol`-implementatie voor de Concept2 PM5 —
/// de referentie-implementatie uit de architectuurvisie (sectie 19/56).
///
/// Bouwt bovenop `CoachOSConnectBluetooth` (generiek, geen PM5-kennis) en
/// `CSAFETransport`/`PM5Frame`/`PM5WorkoutProgrammer` (CSAFE-encoding,
/// geen BLE-kennis). Dit bestand is de enige plek waar die twee lagen
/// samenkomen.
///
/// Bewust een `final class` met `NSLock`, geen `actor` — `DeviceAdapterProtocol.state`
/// is een synchrone `{ get }`-property (zie `Sources/CoachOSConnectCore/Protocols/DeviceAdapterProtocol.swift`),
/// die een actor niet zonder `await` kan aanbieden. Zelfde patroon als
/// `CoreBluetoothManager` uit Sprint 3.
///
/// **Bekende, bewuste beperkingen in deze versie (Sprint 5b):**
///
/// - `pauseWorkout()`/`resumeWorkout()` gooien
///   `PM5Error.unsupportedWorkoutConfiguration` — er is geen bevestigd
///   CSAFE-commando voor pauzeren/hervatten gevonden in het onderzoek.
///   Fysiek pauzeert een roeier de training door te stoppen met roeien, niet
///   door een commando vanaf de telefoon; dit is dus mogelijk geen gat maar
///   een terechte constatering, nog niet bevestigd als zodanig.
/// - `metricsStream()` geeft een lege, direct beëindigde stream terug. Het
///   decoderen van de C2 Rowing Service-karakteristieken (live metrics)
///   hoort bij een latere sprint (roadmap: Sprint 8).
/// - `batteryLevel()` geeft altijd `nil` — geen bevestigde
///   batterij-karakteristiek gevonden in de officiële BLE-spec.
/// - `sync()` is een no-op — het ophalen van workoutresultaten na afloop
///   (GET-commando's) is nog niet onderzocht; hoort bij Workout Sync
///   (roadmap: Sprint 7).
/// - `connect()` verbindt met het eerst gevonden apparaat dat de C2 PM
///   Control Service adverteert. Kiezen tussen meerdere gelijktijdig
///   zichtbare PM5's wordt nog niet ondersteund door deze adapter zelf
///   (dat hoort bij `DeviceDiscoveryController` uit Sprint 4, die apart
///   van deze adapter gebruikt kan worden voor apparaatselectie vóór hier
///   verbonden wordt).
/// - `startWorkout()`/`stopWorkout()` gebruiken de bevestigde
///   `GOINUSE`/`GOFINISHED`-commando's, maar een Concept2-forumdiscussie
///   documenteert onregelmatig gedrag van de PM5-CSAFE-statusmachine
///   specifiek over Bluetooth (in ieder geval op firmware 19). Dit is dus
///   geïmplementeerd volgens het bevestigde commando, maar NIET bevestigd
///   als 100% betrouwbaar in de praktijk — behandel als "geïmplementeerd,
///   nog niet tegen fysieke hardware gevalideerd", conform sectie 69 van
///   het masterdocument.
public final class PM5Adapter: DeviceAdapterProtocol, @unchecked Sendable {

    public static let descriptor = DeviceDescriptor(
        id: "concept2-pm5",
        manufacturer: "Concept2",
        model: "PM5",
        capabilities: [.power, .pace, .strokeRate, .distance, .heartRate]
        // Bewust GEEN .pausable/.resumable — zie beperkingen hierboven.
        // Bewust GEEN .batteryReporting — geen bevestigde characteristic.
    )

    public var descriptor: DeviceDescriptor { Self.descriptor }

    public var state: DeviceState {
        lock.lock()
        defer { lock.unlock() }
        return internalState
    }

    private let bluetooth: BluetoothManagerProtocol
    private let scanTimeoutSeconds: TimeInterval
    private let lock = NSLock()
    private var internalState: DeviceState = .disconnected
    private var deviceId: UUID?
    private var transport: CSAFETransport?
    private var responseObservationTask: Task<Void, Never>?

    /// - Parameter scanTimeoutSeconds: hoe lang `connect()` maximaal wacht
    ///   op een ontdekt PM5-apparaat vóórdat het een expliciete
    ///   `deviceNotFound`-fout geeft, in plaats van voor altijd te
    ///   blijven hangen. Standaard 10 seconden — een redelijke
    ///   software-keuze, geen bevestigd PM5-specifiek getal. Instelbaar
    ///   voor tests.
    public init(bluetooth: BluetoothManagerProtocol, scanTimeoutSeconds: TimeInterval = 10) {
        self.bluetooth = bluetooth
        self.scanTimeoutSeconds = scanTimeoutSeconds
    }

    deinit {
        responseObservationTask?.cancel()
    }

    public func capabilities() -> Set<DeviceCapability> {
        Self.descriptor.capabilities
    }

    public func connect() async throws {
        transition(to: .scanning)

        // Zelfde discipline als de Sprint 4 race-fix: eerst abonneren op de
        // discovery-stream, dán pas scannen starten — anders kan een zeer
        // snelle ontdekking (of, bij een echte implementatie, een
        // discovery-event dat al binnenkomt terwijl `startScan` nog loopt)
        // verloren gaan doordat er nog geen actief abonnement bestaat.
        let discoveryStream = bluetooth.discoveredDevicesStream()
        try await bluetooth.startScan(matching: [PM5BLEConstants.controlServiceUUID])

        let timeoutSeconds = scanTimeoutSeconds

        // Race tussen "een apparaat ontdekt" en "timeout verstreken", zodat
        // connect() nooit voor altijd blijft hangen als er geen PM5 in de
        // buurt is. Beide takken kunnen `nil` opleveren (timeout, of de
        // discovery-stream die onverwacht afsluit) — in beide gevallen is
        // de uitkomst "niet gevonden", nooit een gok.
        let foundDeviceId: UUID? = try await withThrowingTaskGroup(of: UUID?.self) { group in
            group.addTask {
                for await device in discoveryStream {
                    return device.id
                }
                return nil
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                return nil
            }

            defer { group.cancelAll() }
            guard let result = try await group.next() else { return nil }
            return result
        }

        await bluetooth.stopScan()

        guard let foundDeviceId else {
            transition(to: .error(message: "Geen PM5 gevonden tijdens scannen (timeout na \(Int(scanTimeoutSeconds))s)."))
            throw CoachOSConnectError.deviceNotFound(id: "concept2-pm5")
        }

        transition(to: .connecting)
        try await bluetooth.connect(to: foundDeviceId)

        _ = try await bluetooth.discoverServicesAndCharacteristics(
            for: foundDeviceId,
            serviceUUIDs: [PM5BLEConstants.controlServiceUUID]
        )

        let newTransport = CSAFETransport(bluetooth: bluetooth, deviceId: foundDeviceId)

        // Abonneren vóórdat er ooit iets verstuurd wordt — zelfde discipline
        // als de Sprint 4 race-condition-fix: eerst de stream, dan pas actie.
        let responses = try await newTransport.responseStream()
        responseObservationTask = Task {
            for await _ in responses {
                // Sprint 5b: responses worden ontvangen en gedecodeerd
                // (CSAFETransport verwerpt ongeldige frames al), maar nog
                // niet geïnterpreteerd — dat vraagt per-commando-matching
                // die hoort bij een latere verfijning van deze adapter.
                if Task.isCancelled { break }
            }
        }

        lock.lock()
        self.deviceId = foundDeviceId
        self.transport = newTransport
        lock.unlock()

        transition(to: .connected)
    }

    public func disconnect() async throws {
        responseObservationTask?.cancel()
        responseObservationTask = nil

        lock.lock()
        let currentDeviceId = deviceId
        transport = nil
        deviceId = nil
        lock.unlock()

        if let currentDeviceId {
            try await bluetooth.disconnect(from: currentDeviceId)
        }
        transition(to: .disconnected)
    }

    public func sendWorkout(_ workout: UniversalWorkout) async throws {
        guard let transport = currentTransport else { throw CoachOSConnectError.deviceNotConnected }

        let blocks: [PM5WorkoutProgrammer.IntervalBlock]
        do {
            blocks = try PM5WorkoutProgrammer.program(workout)
        } catch let error as PM5Error {
            throw CoachOSConnectError.unknown(reason: error.localizedDescription ?? "PM5-programmeerfout")
        }

        for block in blocks {
            let frame = PM5Frame.encode(block.commands)
            try await transport.send(frame)
        }

        transition(to: .workoutLoaded)
    }

    public func startWorkout() async throws {
        guard let transport = currentTransport else { throw CoachOSConnectError.deviceNotConnected }
        try await transport.send(PM5ControlCommand.goInUse.frame)
        transition(to: .running)
    }

    public func pauseWorkout() async throws {
        throw PM5Error.unsupportedWorkoutConfiguration(
            reason: "Geen bevestigd CSAFE-commando voor pauzeren gevonden. Zie documentatie bij PM5Adapter."
        )
    }

    public func resumeWorkout() async throws {
        throw PM5Error.unsupportedWorkoutConfiguration(
            reason: "Geen bevestigd CSAFE-commando voor hervatten gevonden. Zie documentatie bij PM5Adapter."
        )
    }

    public func stopWorkout() async throws {
        guard let transport = currentTransport else { throw CoachOSConnectError.deviceNotConnected }
        try await transport.send(PM5ControlCommand.goFinished.frame)
        transition(to: .finished)
    }

    public func metricsStream() -> AsyncStream<LiveMetricsBatch> {
        // Sprint 8 (roadmap): decodering van de C2 Rowing Service. Hier
        // bewust een lege, direct beëindigde stream — geen verzonnen data.
        AsyncStream { continuation in continuation.finish() }
    }

    public func sync() async throws {
        // Sprint 7 (roadmap): resultaatophaling via GET-commando's, nog
        // niet onderzocht. Bewust een no-op, geen gegokte implementatie.
    }

    public func batteryLevel() async -> Int? {
        // Geen bevestigde batterij-characteristic in de officiële BLE-spec.
        nil
    }

    // MARK: - Interne helpers

    private var currentTransport: CSAFETransport? {
        lock.lock()
        defer { lock.unlock() }
        return transport
    }

    private func transition(to newState: DeviceState) {
        lock.lock()
        defer { lock.unlock() }
        guard DeviceStateMachine.canTransition(from: internalState, to: newState) else {
            // Ongeldige overgang: state blijft ongewijzigd. Geen crash,
            // maar ook geen stilzwijgend "alsof het gelukt is".
            return
        }
        internalState = newState
    }
}
