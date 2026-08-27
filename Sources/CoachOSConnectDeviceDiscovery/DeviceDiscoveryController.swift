import Foundation
import Combine
import CoachOSConnectBluetooth

/// Presentatielaag boven `BluetoothManagerProtocol`: scan starten/stoppen,
/// de lijst ontdekte apparaten bijhouden, verbinden/verbreken, en de
/// verbindingsstatus per apparaat volgen.
///
/// Kent, net als de Bluetooth-laag waar hij op leunt, geen enkele
/// fabrikant. "Generieke capabilities" (uit de Sprint 4-opdracht) betekent
/// hier: elk ontdekt apparaat wordt getoond zoals de Bluetooth-laag het
/// aanlevert (naam, signaalsterkte, verbindbaarheid) — zonder aan te nemen
/// wélk apparaat het is. Die interpretatie hoort bij een toekomstige
/// adapter (Sprint 5), niet hier.
@MainActor
public final class DeviceDiscoveryController: ObservableObject {
    @Published public private(set) var discoveredDevices: [BluetoothDevice] = []
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var connectionStates: [UUID: BluetoothConnectionState] = [:]
    @Published public private(set) var lastError: BluetoothError?

    private let bluetooth: BluetoothManagerProtocol
    private var discoveryTask: Task<Void, Never>?
    private var connectionObservationTasks: [UUID: Task<Void, Never>] = [:]

    public init(bluetooth: BluetoothManagerProtocol) {
        self.bluetooth = bluetooth
    }

    deinit {
        discoveryTask?.cancel()
        connectionObservationTasks.values.forEach { $0.cancel() }
    }

    // MARK: - Scannen

    public func startScan() async {
        guard !isScanning else { return }
        lastError = nil
        discoveredDevices = DiscoveredDeviceList.cleared()

        do {
            try await bluetooth.startScan(matching: nil)
        } catch let error as BluetoothError {
            lastError = error
            return
        } catch {
            lastError = .unknown(reason: error.localizedDescription)
            return
        }

        isScanning = true
        discoveryTask = Task { [weak self] in
            guard let self else { return }
            let stream = self.bluetooth.discoveredDevicesStream()
            for await device in stream {
                if Task.isCancelled { break }
                await self.handleDiscovery(of: device)
            }
        }
    }

    public func stopScan() async {
        discoveryTask?.cancel()
        discoveryTask = nil
        await bluetooth.stopScan()
        isScanning = false
    }

    private func handleDiscovery(of device: BluetoothDevice) {
        discoveredDevices = DiscoveredDeviceList.merging(device, into: discoveredDevices)
    }

    // MARK: - Verbinding

    public func connect(to deviceId: UUID) async {
        lastError = nil
        do {
            try await bluetooth.connect(to: deviceId)
        } catch let error as BluetoothError {
            lastError = error
        } catch {
            lastError = .unknown(reason: error.localizedDescription)
        }

        // Directe stand van zaken (deterministisch, ook zonder de stream
        // hieronder af te wachten — belangrijk voor testbaarheid).
        connectionStates[deviceId] = await bluetooth.connectionState(for: deviceId)

        observeConnectionState(for: deviceId)
    }

    public func disconnect(from deviceId: UUID) async {
        lastError = nil
        do {
            try await bluetooth.disconnect(from: deviceId)
        } catch let error as BluetoothError {
            lastError = error
        } catch {
            lastError = .unknown(reason: error.localizedDescription)
        }
        connectionStates[deviceId] = await bluetooth.connectionState(for: deviceId)
    }

    public func connectionState(for deviceId: UUID) -> BluetoothConnectionState {
        connectionStates[deviceId] ?? .disconnected
    }

    /// Volgt onverwachte statuswijzigingen (bv. verbindingsverlies) die niet
    /// het resultaat zijn van een expliciete `connect`/`disconnect`-aanroep
    /// vanuit deze controller. Wordt éénmalig per apparaat gestart, bij het
    /// eerste `connect`.
    private func observeConnectionState(for deviceId: UUID) {
        guard connectionObservationTasks[deviceId] == nil else { return }
        connectionObservationTasks[deviceId] = Task { [weak self] in
            guard let self else { return }
            let stream = self.bluetooth.connectionStateStream(for: deviceId)
            for await state in stream {
                if Task.isCancelled { break }
                await self.updateConnectionState(state, for: deviceId)
            }
        }
    }

    private func updateConnectionState(_ state: BluetoothConnectionState, for deviceId: UUID) {
        connectionStates[deviceId] = state
    }
}
