import XCTest
import CoachOSConnectBluetooth
@testable import CoachOSConnectDeviceDiscovery

final class DeviceDiscoveryControllerTests: XCTestCase {

    // MARK: - DiscoveredDeviceList (pure logica, geen async nodig)

    func test_discoveredDeviceList_dedupesOnRediscoveryAndKeepsLatestRSSI() {
        let id = UUID()
        let first = BluetoothDevice(id: id, name: "PM5", rssi: -70, advertisedServiceUUIDs: [], isConnectable: true)
        let second = BluetoothDevice(id: id, name: "PM5", rssi: -40, advertisedServiceUUIDs: [], isConnectable: true)

        var list = DiscoveredDeviceList.merging(first, into: [])
        list = DiscoveredDeviceList.merging(second, into: list)

        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list.first?.rssi, -40)
    }

    func test_discoveredDeviceList_sortsBySignalStrengthStrongestFirst() {
        let weak = BluetoothDevice(id: UUID(), name: "Weak", rssi: -80, advertisedServiceUUIDs: [], isConnectable: true)
        let strong = BluetoothDevice(id: UUID(), name: "Strong", rssi: -35, advertisedServiceUUIDs: [], isConnectable: true)

        var list: [BluetoothDevice] = []
        list = DiscoveredDeviceList.merging(weak, into: list)
        list = DiscoveredDeviceList.merging(strong, into: list)

        XCTAssertEqual(list.map(\.name), ["Strong", "Weak"])
    }

    // MARK: - DeviceDiscoveryController (met MockBluetoothManager, geen hardware)

    @MainActor
    func test_startScan_delegatesToBluetoothManagerAndSetsIsScanning() async {
        let mock = MockBluetoothManager()
        let controller = DeviceDiscoveryController(bluetooth: mock)

        await controller.startScan()

        XCTAssertTrue(controller.isScanning)
        XCTAssertEqual(mock.scanStartCount, 1)
    }

    @MainActor
    func test_startScan_publishesDiscoveredDevices() async {
        let mock = MockBluetoothManager()
        let controller = DeviceDiscoveryController(bluetooth: mock)
        let device = BluetoothDevice(id: UUID(), name: "Test Rower", rssi: -55, advertisedServiceUUIDs: ["1826"], isConnectable: true)

        await controller.startScan()
        mock.simulateDiscovery(of: device)

        // Geeft de achtergrond-Task die de stream consumeert de kans om te lopen.
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(controller.discoveredDevices.map(\.id), [device.id])
    }

    @MainActor
    func test_connect_updatesConnectionStateDeterministically() async {
        let mock = MockBluetoothManager()
        let controller = DeviceDiscoveryController(bluetooth: mock)
        let deviceId = UUID()

        XCTAssertEqual(controller.connectionState(for: deviceId), .disconnected)

        await controller.connect(to: deviceId)

        XCTAssertEqual(controller.connectionState(for: deviceId), .connected)
        XCTAssertEqual(mock.connectCallCount, 1)
    }

    @MainActor
    func test_connect_failurePublishesLastError() async {
        let mock = MockBluetoothManager()
        mock.stubError(BluetoothError.connectionFailed(reason: "test"), for: "connect")
        let controller = DeviceDiscoveryController(bluetooth: mock)

        await controller.connect(to: UUID())

        XCTAssertEqual(controller.lastError, .connectionFailed(reason: "test"))
    }

    @MainActor
    func test_stopScan_stopsUnderlyingScanAndClearsScanningFlag() async {
        let mock = MockBluetoothManager()
        let controller = DeviceDiscoveryController(bluetooth: mock)

        await controller.startScan()
        await controller.stopScan()

        XCTAssertFalse(controller.isScanning)
        XCTAssertEqual(mock.scanStopCount, 1)
    }
}
