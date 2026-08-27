import Foundation
import CoreBluetooth

/// CoreBluetooth-gebaseerde implementatie van `BluetoothManagerProtocol`.
///
/// Dit is de enige plek in de hele codebase die `import CoreBluetooth` doet.
/// Alles hierboven (Device Layer, toekomstige adapters, use cases, UI) kent
/// alleen het protocol en de generieke types die daarbij horen
/// (`BluetoothDevice`, `BLEService`, `BLECharacteristicAddress`, ...).
///
/// Bekende beperking in deze Sprint 3-versie (bewust, geen verborgen gok):
/// `discoveredDevicesStream()` ondersteunt één actieve consument tegelijk —
/// een nieuwe aanroep tijdens een lopende scan sluit de vorige stream af.
/// Voor Sprint 4 (device discovery UI) is dat voldoende; multi-subscriber
/// scanning kan later worden toegevoegd zonder het protocol te wijzigen.
public final class CoreBluetoothManager: NSObject, BluetoothManagerProtocol, @unchecked Sendable {

    private let logger: BluetoothLogging
    private let lock = NSLock()

    private var central: CBCentralManager!
    private var centralReadyContinuations: [CheckedContinuation<Void, Error>] = []
    private var isCentralReady = false

    private var peripherals: [UUID: CBPeripheral] = [:]
    private var connectionStates: [UUID: BluetoothConnectionState] = [:]
    private var connectionStateContinuations: [UUID: [AsyncStream<BluetoothConnectionState>.Continuation]] = [:]
    private var reconnectPolicies: [UUID: BluetoothReconnectPolicy] = [:]
    private var reconnectAttempts: [UUID: Int] = [:]

    private var connectContinuations: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var disconnectContinuations: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var serviceDiscoveryContinuations: [UUID: CheckedContinuation<[BLEService], Error>] = [:]
    private var serviceDiscoveryFilter: [UUID: [String]?] = [:]

    private var writeContinuations: [CharacteristicKey: CheckedContinuation<Void, Error>] = [:]
    private var readContinuations: [CharacteristicKey: CheckedContinuation<Data, Error>] = [:]
    private var subscriptionContinuations: [CharacteristicKey: AsyncStream<Data>.Continuation] = [:]
    private var discoveredCharacteristics: [UUID: [CBUUID: CBCharacteristic]] = [:]

    private var discoveredDeviceContinuation: AsyncStream<BluetoothDevice>.Continuation?

    private struct CharacteristicKey: Hashable {
        let deviceId: UUID
        let address: BLECharacteristicAddress
    }

    public init(logger: BluetoothLogging = OSBluetoothLogger()) {
        self.logger = logger
        super.init()
        // Eigen serial queue: delegate-callbacks komen niet op de main
        // thread binnen, zodat UI-werk hier niet per ongeluk op leunt.
        let queue = DispatchQueue(label: "coachos.connect.corebluetooth", qos: .userInitiated)
        self.central = CBCentralManager(delegate: self, queue: queue)
    }

    // MARK: - Scannen

    public func startScan(matching serviceUUIDs: [String]?) async throws {
        try await waitUntilReady()
        logger.log(.info, "Start scan (services: \(serviceUUIDs?.joined(separator: ",") ?? "alle"))")
        let uuids = serviceUUIDs?.map { CBUUID(string: $0) }
        central.scanForPeripherals(withServices: uuids, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    public func stopScan() async {
        logger.log(.info, "Scan gestopt")
        central.stopScan()
        lock.lock()
        discoveredDeviceContinuation?.finish()
        discoveredDeviceContinuation = nil
        lock.unlock()
    }

    public func discoveredDevicesStream() -> AsyncStream<BluetoothDevice> {
        AsyncStream { continuation in
            lock.lock()
            // Sprint 3-beperking: één actieve consument, zie type-doc hierboven.
            discoveredDeviceContinuation?.finish()
            discoveredDeviceContinuation = continuation
            lock.unlock()

            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.lock()
                self.discoveredDeviceContinuation = nil
                self.lock.unlock()
            }
        }
    }

    // MARK: - Verbinding

    public func connect(to deviceId: UUID) async throws {
        try await waitUntilReady()
        guard let peripheral = lockedValue(peripherals[deviceId]) else {
            throw BluetoothError.deviceNotFound(id: deviceId)
        }

        setConnectionState(.connecting, for: deviceId)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.lock.lock()
            self.connectContinuations[deviceId] = continuation
            self.lock.unlock()
            self.central.connect(peripheral, options: nil)
        }
    }

    public func disconnect(from deviceId: UUID) async throws {
        guard let peripheral = lockedValue(peripherals[deviceId]) else {
            throw BluetoothError.deviceNotFound(id: deviceId)
        }

        setConnectionState(.disconnecting, for: deviceId)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.lock.lock()
            self.disconnectContinuations[deviceId] = continuation
            self.lock.unlock()
            self.central.cancelPeripheralConnection(peripheral)
        }
    }

    public func connectionState(for deviceId: UUID) async -> BluetoothConnectionState {
        lockedValue(connectionStates[deviceId]) ?? .disconnected
    }

    public func connectionStateStream(for deviceId: UUID) -> AsyncStream<BluetoothConnectionState> {
        AsyncStream { continuation in
            self.lock.lock()
            var existing = self.connectionStateContinuations[deviceId] ?? []
            existing.append(continuation)
            self.connectionStateContinuations[deviceId] = existing
            let current = self.connectionStates[deviceId] ?? .disconnected
            self.lock.unlock()

            continuation.yield(current)

            continuation.onTermination = { [weak self] _ in
                // Individuele continuations opruimen gebeurt bewust niet
                // per-instantie (AsyncStream geeft geen identiteit terug);
                // gestopte streams blijven verder inert totdat de volgende
                // state-update ze als geen-op negeert.
                self?.logger.log(.debug, "connectionStateStream beëindigd voor \(deviceId)")
            }
        }
    }

    public func setReconnectPolicy(_ policy: BluetoothReconnectPolicy, for deviceId: UUID) async {
        lock.lock()
        reconnectPolicies[deviceId] = policy
        reconnectAttempts[deviceId] = 0
        lock.unlock()
    }

    // MARK: - Services & characteristics

    public func discoverServicesAndCharacteristics(for deviceId: UUID, serviceUUIDs: [String]?) async throws -> [BLEService] {
        guard let peripheral = lockedValue(peripherals[deviceId]) else {
            throw BluetoothError.deviceNotFound(id: deviceId)
        }
        guard peripheral.state == .connected else {
            throw BluetoothError.notConnected
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[BLEService], Error>) in
            self.lock.lock()
            self.serviceDiscoveryContinuations[deviceId] = continuation
            self.serviceDiscoveryFilter[deviceId] = serviceUUIDs
            self.lock.unlock()
            peripheral.discoverServices(serviceUUIDs?.map { CBUUID(string: $0) })
        }
    }

    // MARK: - Lezen, schrijven, abonneren

    public func write(_ data: Data, to characteristic: BLECharacteristicAddress, on deviceId: UUID, expectingResponse: Bool) async throws {
        let (peripheral, cbCharacteristic) = try resolvedCharacteristic(characteristic, on: deviceId)

        if !expectingResponse {
            peripheral.writeValue(data, for: cbCharacteristic, type: .withoutResponse)
            return
        }

        let key = CharacteristicKey(deviceId: deviceId, address: characteristic)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.lock.lock()
            self.writeContinuations[key] = continuation
            self.lock.unlock()
            peripheral.writeValue(data, for: cbCharacteristic, type: .withResponse)
        }
    }

    public func read(_ characteristic: BLECharacteristicAddress, on deviceId: UUID) async throws -> Data {
        let (peripheral, cbCharacteristic) = try resolvedCharacteristic(characteristic, on: deviceId)
        let key = CharacteristicKey(deviceId: deviceId, address: characteristic)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            self.lock.lock()
            self.readContinuations[key] = continuation
            self.lock.unlock()
            peripheral.readValue(for: cbCharacteristic)
        }
    }

    public func subscribe(to characteristic: BLECharacteristicAddress, on deviceId: UUID) async throws -> AsyncStream<Data> {
        let (peripheral, cbCharacteristic) = try resolvedCharacteristic(characteristic, on: deviceId)
        let key = CharacteristicKey(deviceId: deviceId, address: characteristic)

        return AsyncStream { continuation in
            self.lock.lock()
            self.subscriptionContinuations[key] = continuation
            self.lock.unlock()
            peripheral.setNotifyValue(true, for: cbCharacteristic)

            continuation.onTermination = { [weak self] _ in
                self?.lock.lock()
                self?.subscriptionContinuations[key] = nil
                self?.lock.unlock()
                peripheral.setNotifyValue(false, for: cbCharacteristic)
            }
        }
    }

    public func unsubscribe(from characteristic: BLECharacteristicAddress, on deviceId: UUID) async throws {
        let (peripheral, cbCharacteristic) = try resolvedCharacteristic(characteristic, on: deviceId)
        let key = CharacteristicKey(deviceId: deviceId, address: characteristic)
        peripheral.setNotifyValue(false, for: cbCharacteristic)
        lock.lock()
        subscriptionContinuations[key]?.finish()
        subscriptionContinuations[key] = nil
        lock.unlock()
    }

    // MARK: - Interne helpers

    private func waitUntilReady() async throws {
        if lockedValue(isCentralReady) { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.lock.lock()
            self.centralReadyContinuations.append(continuation)
            self.lock.unlock()
        }
    }

    private func resolvedCharacteristic(_ address: BLECharacteristicAddress, on deviceId: UUID) throws -> (CBPeripheral, CBCharacteristic) {
        guard let peripheral = lockedValue(peripherals[deviceId]) else {
            throw BluetoothError.deviceNotFound(id: deviceId)
        }
        guard peripheral.state == .connected else {
            throw BluetoothError.notConnected
        }
        guard let characteristic = lockedValue(discoveredCharacteristics[deviceId]?[CBUUID(string: address.characteristicUUID)]) else {
            throw BluetoothError.characteristicNotFound(uuid: address.characteristicUUID)
        }
        return (peripheral, characteristic)
    }

    private func lockedValue<T>(_ expression: @autoclosure () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return expression()
    }

    private func setConnectionState(_ state: BluetoothConnectionState, for deviceId: UUID) {
        lock.lock()
        connectionStates[deviceId] = state
        let continuations = connectionStateContinuations[deviceId] ?? []
        lock.unlock()
        for continuation in continuations {
            continuation.yield(state)
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension CoreBluetoothManager: CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            logger.log(.info, "Bluetooth beschikbaar (poweredOn)")
            lock.lock()
            isCentralReady = true
            let waiters = centralReadyContinuations
            centralReadyContinuations.removeAll()
            lock.unlock()
            waiters.forEach { $0.resume() }

        case .unauthorized:
            failAllPending(with: .bluetoothUnauthorized)

        case .poweredOff, .unsupported, .resetting, .unknown:
            failAllPending(with: .bluetoothUnavailable)

        @unknown default:
            failAllPending(with: .unknown(reason: "Onbekende CBManagerState"))
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        lock.lock()
        peripherals[peripheral.identifier] = peripheral
        let continuation = discoveredDeviceContinuation
        lock.unlock()

        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.map { $0.uuidString } ?? []
        let isConnectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue ?? false

        let device = BluetoothDevice(
            id: peripheral.identifier,
            name: peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String,
            rssi: RSSI.intValue,
            advertisedServiceUUIDs: serviceUUIDs,
            isConnectable: isConnectable
        )
        continuation?.yield(device)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        setConnectionState(.connected, for: peripheral.identifier)
        lock.lock()
        reconnectAttempts[peripheral.identifier] = 0
        let continuation = connectContinuations.removeValue(forKey: peripheral.identifier)
        lock.unlock()
        continuation?.resume()
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let reason = error?.localizedDescription ?? "onbekende reden"
        setConnectionState(.failed(reason: reason), for: peripheral.identifier)
        lock.lock()
        let continuation = connectContinuations.removeValue(forKey: peripheral.identifier)
        lock.unlock()
        continuation?.resume(throwing: BluetoothError.connectionFailed(reason: reason))
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let deviceId = peripheral.identifier

        lock.lock()
        let explicitDisconnect = disconnectContinuations.removeValue(forKey: deviceId)
        let policy = reconnectPolicies[deviceId] ?? .manual
        let attempts = reconnectAttempts[deviceId] ?? 0
        lock.unlock()

        if let explicitDisconnect {
            setConnectionState(.disconnected, for: deviceId)
            explicitDisconnect.resume()
            return
        }

        // Onverwacht verbindingsverlies: alleen automatisch herverbinden als
        // dat expliciet is aangevraagd via `setReconnectPolicy`.
        if case .automatic(let maxAttempts) = policy, maxAttempts.map({ attempts < $0 }) ?? true {
            logger.log(.warning, "Onverwacht verbindingsverlies met \(deviceId), reconnect-poging \(attempts + 1)")
            setConnectionState(.reconnecting, for: deviceId)
            lock.lock()
            reconnectAttempts[deviceId] = attempts + 1
            lock.unlock()
            central.connect(peripheral, options: nil)
        } else {
            let reason = error?.localizedDescription ?? "verbinding verbroken"
            setConnectionState(error == nil ? .disconnected : .failed(reason: reason), for: deviceId)
        }
    }

    private func failAllPending(with error: BluetoothError) {
        logger.log(.error, error.localizedDescription ?? "Bluetooth-fout")
        lock.lock()
        isCentralReady = false
        let readyWaiters = centralReadyContinuations
        centralReadyContinuations.removeAll()
        let connects = connectContinuations
        connectContinuations.removeAll()
        lock.unlock()

        readyWaiters.forEach { $0.resume(throwing: error) }
        connects.values.forEach { $0.resume(throwing: error) }
    }
}

// MARK: - CBPeripheralDelegate

extension CoreBluetoothManager: CBPeripheralDelegate {

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            failServiceDiscovery(for: peripheral.identifier, error: .serviceNotFound(uuid: error.localizedDescription))
            return
        }
        let services = peripheral.services ?? []
        guard !services.isEmpty else {
            completeServiceDiscovery(for: peripheral)
            return
        }
        for service in services {
            let filter = lockedValue(serviceDiscoveryFilter[peripheral.identifier] ?? nil)
            peripheral.discoverCharacteristics(nil, for: service)
            _ = filter // filter is toegepast door CoreBluetooth zelf bij discoverServices; hier alleen ter documentatie.
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            failServiceDiscovery(for: peripheral.identifier, error: .characteristicNotFound(uuid: error.localizedDescription))
            return
        }

        lock.lock()
        var characteristicsByUUID = discoveredCharacteristics[peripheral.identifier] ?? [:]
        for characteristic in service.characteristics ?? [] {
            characteristicsByUUID[characteristic.uuid] = characteristic
        }
        discoveredCharacteristics[peripheral.identifier] = characteristicsByUUID
        lock.unlock()

        let remaining = peripheral.services?.filter { $0.characteristics == nil } ?? []
        if remaining.isEmpty {
            completeServiceDiscovery(for: peripheral)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let address = address(for: characteristic) else { return }
        let key = CharacteristicKey(deviceId: peripheral.identifier, address: address)
        lock.lock()
        let continuation = writeContinuations.removeValue(forKey: key)
        lock.unlock()

        if let error {
            continuation?.resume(throwing: BluetoothError.writeFailed(reason: error.localizedDescription))
        } else {
            continuation?.resume()
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let address = address(for: characteristic) else { return }
        let key = CharacteristicKey(deviceId: peripheral.identifier, address: address)

        if let error {
            lock.lock()
            let readContinuation = readContinuations.removeValue(forKey: key)
            lock.unlock()
            readContinuation?.resume(throwing: BluetoothError.readFailed(reason: error.localizedDescription))
            return
        }

        let data = characteristic.value ?? Data()

        lock.lock()
        let readContinuation = readContinuations.removeValue(forKey: key)
        let subscription = subscriptionContinuations[key]
        lock.unlock()

        if let readContinuation {
            readContinuation.resume(returning: data)
        } else {
            subscription?.yield(data)
        }
    }

    private func address(for characteristic: CBCharacteristic) -> BLECharacteristicAddress? {
        guard let serviceUUID = characteristic.service?.uuid.uuidString else { return nil }
        return BLECharacteristicAddress(serviceUUID: serviceUUID, characteristicUUID: characteristic.uuid.uuidString)
    }

    private func completeServiceDiscovery(for peripheral: CBPeripheral) {
        let services: [BLEService] = (peripheral.services ?? []).map { service in
            let characteristics: [BLECharacteristic] = (service.characteristics ?? []).map { characteristic in
                BLECharacteristic(
                    address: BLECharacteristicAddress(serviceUUID: service.uuid.uuidString, characteristicUUID: characteristic.uuid.uuidString),
                    supportsRead: characteristic.properties.contains(.read),
                    supportsWrite: characteristic.properties.contains(.write),
                    supportsWriteWithoutResponse: characteristic.properties.contains(.writeWithoutResponse),
                    supportsNotify: characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate)
                )
            }
            return BLEService(serviceUUID: service.uuid.uuidString, characteristics: characteristics)
        }

        lock.lock()
        let continuation = serviceDiscoveryContinuations.removeValue(forKey: peripheral.identifier)
        serviceDiscoveryFilter[peripheral.identifier] = nil
        lock.unlock()
        continuation?.resume(returning: services)
    }

    private func failServiceDiscovery(for deviceId: UUID, error: BluetoothError) {
        lock.lock()
        let continuation = serviceDiscoveryContinuations.removeValue(forKey: deviceId)
        serviceDiscoveryFilter[deviceId] = nil
        lock.unlock()
        continuation?.resume(throwing: error)
    }
}
