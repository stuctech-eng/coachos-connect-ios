import XCTest
@testable import CoachOSConnectBluetooth

final class BluetoothManagerTests: XCTestCase {

    // MARK: - BluetoothStateMachine

    func test_bluetoothStateMachine_allowsValidConnectionFlow() {
        XCTAssertTrue(BluetoothStateMachine.canTransition(from: .disconnected, to: .connecting))
        XCTAssertTrue(BluetoothStateMachine.canTransition(from: .connecting, to: .connected))
        XCTAssertTrue(BluetoothStateMachine.canTransition(from: .connected, to: .reconnecting))
        XCTAssertTrue(BluetoothStateMachine.canTransition(from: .reconnecting, to: .connected))
        XCTAssertTrue(BluetoothStateMachine.canTransition(from: .connected, to: .disconnecting))
        XCTAssertTrue(BluetoothStateMachine.canTransition(from: .disconnecting, to: .disconnected))
    }

    func test_bluetoothStateMachine_rejectsInvalidConnectionFlow() {
        // Je kunt niet vanuit losgekoppeld direct "verbonden" worden zonder
        // ooit door .connecting te zijn gegaan.
        XCTAssertFalse(BluetoothStateMachine.canTransition(from: .disconnected, to: .connected))
        // Losgekoppeld kan niet rechtstreeks naar reconnecting (er is nooit
        // een bestaande verbinding geweest om te herstellen).
        XCTAssertFalse(BluetoothStateMachine.canTransition(from: .disconnected, to: .reconnecting))
    }

    func test_bluetoothStateMachine_alwaysAllowsDisconnectedAndFailed() {
        for state: BluetoothConnectionState in [.connecting, .connected, .reconnecting, .disconnecting] {
            XCTAssertTrue(BluetoothStateMachine.canTransition(from: state, to: .disconnected))
            XCTAssertTrue(BluetoothStateMachine.canTransition(from: state, to: .failed(reason: "test")))
        }
    }

    // MARK: - MockBluetoothManager: bewijst dat het protocol testbaar is zonder hardware

    func test_mockBluetoothManager_discoveryStreamYieldsSimulatedDevices() async {
        let mock = MockBluetoothManager()
        let device = BluetoothDevice(id: UUID(), name: "Test Device", rssi: -50, advertisedServiceUUIDs: ["1234"], isConnectable: true)

        let stream = mock.discoveredDevicesStream()
        var iterator = stream.makeAsyncIterator()

        mock.simulateDiscovery(of: device)

        let received = await iterator.next()
        XCTAssertEqual(received, device)
    }

    func test_mockBluetoothManager_connectUpdatesConnectionState() async throws {
        let mock = MockBluetoothManager()
        let deviceId = UUID()

        // `await` mag niet direct in een XCTAssert-autoclosure staan (die is
        // niet async) — daarom eerst in een lokale let vastleggen, dan pas
        // asserten. Zie changelog voor de aanleiding van deze fix.
        let stateBeforeConnect = await mock.connectionState(for: deviceId)
        XCTAssertEqual(stateBeforeConnect, .disconnected)

        try await mock.connect(to: deviceId)

        let stateAfterConnect = await mock.connectionState(for: deviceId)
        XCTAssertEqual(stateAfterConnect, .connected)
        XCTAssertEqual(mock.connectCallCount, 1)
    }

    func test_mockBluetoothManager_writeRecordsValueAndCanBeStubbedToFail() async {
        let mock = MockBluetoothManager()
        let deviceId = UUID()
        let address = BLECharacteristicAddress(serviceUUID: "1801", characteristicUUID: "2A05")
        let payload = Data([0x01, 0x02, 0x03])

        do {
            try await mock.write(payload, to: address, on: deviceId, expectingResponse: true)
        } catch {
            XCTFail("Onverwachte fout: \(error)")
        }
        XCTAssertEqual(mock.writtenValues.first?.data, payload)

        mock.stubError(BluetoothError.notConnected, for: "write")
        do {
            try await mock.write(payload, to: address, on: deviceId, expectingResponse: true)
            XCTFail("Verwachtte BluetoothError.notConnected")
        } catch BluetoothError.notConnected {
            // verwacht
        } catch {
            XCTFail("Onverwachte fout: \(error)")
        }
    }

    func test_mockBluetoothManager_subscriptionYieldsSimulatedNotifications() async throws {
        let mock = MockBluetoothManager()
        let deviceId = UUID()
        let address = BLECharacteristicAddress(serviceUUID: "1826", characteristicUUID: "2AD2")

        let stream = try await mock.subscribe(to: address, on: deviceId)
        var iterator = stream.makeAsyncIterator()

        mock.simulateNotification(Data([0xAA]), for: address, on: deviceId)

        let received = await iterator.next()
        XCTAssertEqual(received, Data([0xAA]))
    }
}
