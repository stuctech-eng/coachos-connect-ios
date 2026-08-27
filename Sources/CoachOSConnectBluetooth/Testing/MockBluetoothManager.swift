import Foundation

/// In-memory testdubbel van `BluetoothManagerProtocol`. Laat toekomstige
/// adapters (Sprint 5: `PM5Adapter`) en use cases getest worden zonder
/// echte Bluetooth-hardware, een fysiek iPhone of een simulator.
///
/// Bewust in de hoofdmodule (niet in het testtarget) zodat andere modules
/// (bijv. een toekomstig `CoachOSConnectData`-testtarget of een
/// PM5-adapter-testtarget) 'm kunnen hergebruiken via
/// `import CoachOSConnectBluetooth`.
public final class MockBluetoothManager: BluetoothManagerProtocol, @unchecked Sendable {
    private let lock = NSLock()

    public private(set) var scanStartCount = 0
    public private(set) var scanStopCount = 0
    public private(set) var connectCallCount = 0
    public private(set) var writtenValues: [(address: BLECharacteristicAddress, deviceId: UUID, data: Data)] = []

    private var connectionStates: [UUID: BluetoothConnectionState] = [:]
    private var connectionStateContinuations: [UUID: AsyncStream<BluetoothConnectionState>.Continuation] = [:]
    private var deviceDiscoveryContinuation: AsyncStream<BluetoothDevice>.Continuation?
    private var servicesByDevice: [UUID: [BLEService]] = [:]
    private var readResponses: [CharacteristicKey: Data] = [:]
    private var subscriptionContinuations: [CharacteristicKey: AsyncStream<Data>.Continuation] = [:]
    private var errorsToThrow: [String: Error] = [:]

    private struct CharacteristicKey: Hashable {
        let deviceId: UUID
        let address: BLECharacteristicAddress
    }

    public init() {}

    // MARK: - Testcontrole (aangeroepen vanuit tests, niet vanuit productiecode)

    public func simulateDiscovery(of device: BluetoothDevice) {
        lock.lock()
        let continuation = deviceDiscoveryContinuation
        lock.unlock()
        continuation?.yield(device)
    }

    public func simulateConnectionStateChange(_ state: BluetoothConnectionState, for deviceId: UUID) {
        lock.lock()
        connectionStates[deviceId] = state
        let continuation = connectionStateContinuations[deviceId]
        lock.unlock()
        continuation?.yield(state)
    }

    public func stubServices(_ services: [BLEService], for deviceId: UUID) {
        lock.lock()
        servicesByDevice[deviceId] = services
        lock.unlock()
    }

    public func stubReadResponse(_ data: Data, for address: BLECharacteristicAddress, on deviceId: UUID) {
        lock.lock()
        readResponses[CharacteristicKey(deviceId: deviceId, address: address)] = data
        lock.unlock()
    }

    public func simulateNotification(_ data: Data, for address: BLECharacteristicAddress, on deviceId: UUID) {
        lock.lock()
        let continuation = subscriptionContinuations[CharacteristicKey(deviceId: deviceId, address: address)]
        lock.unlock()
        continuation?.yield(data)
    }

    public func stubError(_ error: Error, for operation: String) {
        lock.lock()
        errorsToThrow[operation] = error
        lock.unlock()
    }

    // MARK: - BluetoothManagerProtocol

    public func startScan(matching serviceUUIDs: [String]?) async throws {
        if let error = lockedError(for: "startScan") { throw error }
        lock.lock(); scanStartCount += 1; lock.unlock()
    }

    public func stopScan() async {
        lock.lock(); scanStopCount += 1; lock.unlock()
    }

    public func discoveredDevicesStream() -> AsyncStream<BluetoothDevice> {
        AsyncStream { continuation in
            self.lock.lock()
            self.deviceDiscoveryContinuation = continuation
            self.lock.unlock()
        }
    }

    public func connect(to deviceId: UUID) async throws {
        if let error = lockedError(for: "connect") { throw error }
        lock.lock(); connectCallCount += 1; lock.unlock()
        simulateConnectionStateChange(.connected, for: deviceId)
    }

    public func disconnect(from deviceId: UUID) async throws {
        if let error = lockedError(for: "disconnect") { throw error }
        simulateConnectionStateChange(.disconnected, for: deviceId)
    }

    public func connectionState(for deviceId: UUID) async -> BluetoothConnectionState {
        lock.lock()
        defer { lock.unlock() }
        return connectionStates[deviceId] ?? .disconnected
    }

    public func connectionStateStream(for deviceId: UUID) -> AsyncStream<BluetoothConnectionState> {
        AsyncStream { continuation in
            self.lock.lock()
            self.connectionStateContinuations[deviceId] = continuation
            let current = self.connectionStates[deviceId] ?? .disconnected
            self.lock.unlock()
            continuation.yield(current)
        }
    }

    public func setReconnectPolicy(_ policy: BluetoothReconnectPolicy, for deviceId: UUID) async {
        // Mock houdt geen reconnect-gedrag bij; puur voor interface-compatibiliteit.
    }

    public func discoverServicesAndCharacteristics(for deviceId: UUID, serviceUUIDs: [String]?) async throws -> [BLEService] {
        if let error = lockedError(for: "discoverServicesAndCharacteristics") { throw error }
        lock.lock()
        let services = servicesByDevice[deviceId] ?? []
        lock.unlock()
        return services
    }

    public func write(_ data: Data, to characteristic: BLECharacteristicAddress, on deviceId: UUID, expectingResponse: Bool) async throws {
        if let error = lockedError(for: "write") { throw error }
        lock.lock()
        writtenValues.append((address: characteristic, deviceId: deviceId, data: data))
        lock.unlock()
    }

    public func read(_ characteristic: BLECharacteristicAddress, on deviceId: UUID) async throws -> Data {
        if let error = lockedError(for: "read") { throw error }
        lock.lock()
        let data = readResponses[CharacteristicKey(deviceId: deviceId, address: characteristic)]
        lock.unlock()
        guard let data else {
            throw BluetoothError.characteristicNotFound(uuid: characteristic.characteristicUUID)
        }
        return data
    }

    public func subscribe(to characteristic: BLECharacteristicAddress, on deviceId: UUID) async throws -> AsyncStream<Data> {
        if let error = lockedError(for: "subscribe") { throw error }
        let key = CharacteristicKey(deviceId: deviceId, address: characteristic)
        return AsyncStream { continuation in
            self.lock.lock()
            self.subscriptionContinuations[key] = continuation
            self.lock.unlock()
        }
    }

    public func unsubscribe(from characteristic: BLECharacteristicAddress, on deviceId: UUID) async throws {
        let key = CharacteristicKey(deviceId: deviceId, address: characteristic)
        lock.lock()
        subscriptionContinuations[key]?.finish()
        subscriptionContinuations[key] = nil
        lock.unlock()
    }

    private func lockedError(for operation: String) -> Error? {
        lock.lock()
        defer { lock.unlock() }
        return errorsToThrow[operation]
    }
}
