import XCTest
import CoachOSConnectCore
import CoachOSConnectBluetooth
@testable import CoachOSConnectPM5

final class PM5AdapterTests: XCTestCase {

    func test_descriptor_declaresConfirmedCapabilitiesOnly() {
        let descriptor = PM5Adapter.descriptor
        XCTAssertEqual(descriptor.manufacturer, "Concept2")
        XCTAssertEqual(descriptor.model, "PM5")
        XCTAssertTrue(descriptor.capabilities.contains(.power))
        XCTAssertTrue(descriptor.capabilities.contains(.pace))
        // Bewust niet geclaimd — geen bevestigd pauze/hervat-commando.
        XCTAssertFalse(descriptor.capabilities.contains(.pausable))
        XCTAssertFalse(descriptor.capabilities.contains(.resumable))
        XCTAssertFalse(descriptor.capabilities.contains(.batteryReporting))
    }

    func test_initialState_isDisconnected() {
        let adapter = PM5Adapter(bluetooth: MockBluetoothManager())
        XCTAssertEqual(adapter.state, .disconnected)
    }

    /// Bevestigt de fix voor de race/hang-bug die tijdens het bouwen zelf
    /// ontdekt werd: zonder timeout zou `connect()` voor altijd blijven
    /// wachten als er geen PM5 gevonden wordt (de discovery-stream sluit
    /// nooit vanzelf af). Korte timeout hier, puur voor test-snelheid.
    func test_connect_withNoDiscoveredDevice_throwsDeviceNotFoundAfterTimeout_insteadOfHanging() async {
        let mock = MockBluetoothManager()
        let adapter = PM5Adapter(bluetooth: mock, scanTimeoutSeconds: 0.05)

        do {
            try await adapter.connect()
            XCTFail("Verwachtte CoachOSConnectError.deviceNotFound")
        } catch CoachOSConnectError.deviceNotFound(let id) {
            XCTAssertEqual(id, "concept2-pm5")
        } catch {
            XCTFail("Onverwachte fout: \(error)")
        }

        guard case .error = adapter.state else {
            return XCTFail("Verwachtte .error-state na mislukte scan, kreeg \(adapter.state)")
        }
    }

    func test_connect_withDiscoveredDevice_transitionsToConnectedAndCallsBluetoothManager() async throws {
        let mock = MockBluetoothManager()
        let adapter = PM5Adapter(bluetooth: mock, scanTimeoutSeconds: 5)
        let deviceId = UUID()

        let connectTask = Task { try await adapter.connect() }

        // Geef de scan-consumptie een kans om te starten, simuleer dan een
        // ontdekking van "de" PM5.
        try? await Task.sleep(nanoseconds: 20_000_000)
        let device = BluetoothDevice(id: deviceId, name: "PM5 123456", rssi: -40, advertisedServiceUUIDs: [PM5BLEConstants.controlServiceUUID], isConnectable: true)
        mock.stubServices([
            BLEService(serviceUUID: PM5BLEConstants.controlServiceUUID, characteristics: [
                BLECharacteristic(
                    address: BLECharacteristicAddress(serviceUUID: PM5BLEConstants.controlServiceUUID, characteristicUUID: PM5BLEConstants.controlReceiveCharacteristicUUID),
                    supportsRead: false, supportsWrite: true, supportsWriteWithoutResponse: true, supportsNotify: false
                ),
                BLECharacteristic(
                    address: BLECharacteristicAddress(serviceUUID: PM5BLEConstants.controlServiceUUID, characteristicUUID: PM5BLEConstants.controlTransmitCharacteristicUUID),
                    supportsRead: true, supportsWrite: false, supportsWriteWithoutResponse: false, supportsNotify: true
                )
            ])
        ], for: deviceId)
        mock.simulateDiscovery(of: device)

        try await connectTask.value

        XCTAssertEqual(adapter.state, .connected)
        XCTAssertEqual(mock.connectCallCount, 1)
    }

    func test_sendWorkout_beforeConnect_throwsDeviceNotConnected() async {
        let adapter = PM5Adapter(bluetooth: MockBluetoothManager())
        let workout = UniversalWorkout(sourceId: "t", title: "t", sport: .rowing, blocks: [])

        do {
            try await adapter.sendWorkout(workout)
            XCTFail("Verwachtte CoachOSConnectError.deviceNotConnected")
        } catch CoachOSConnectError.deviceNotConnected {
            // verwacht
        } catch {
            XCTFail("Onverwachte fout: \(error)")
        }
    }

    func test_pauseWorkout_isExplicitlyUnsupported_notGuessed() async {
        let adapter = PM5Adapter(bluetooth: MockBluetoothManager())

        do {
            try await adapter.pauseWorkout()
            XCTFail("Verwachtte PM5Error.unsupportedWorkoutConfiguration")
        } catch PM5Error.unsupportedWorkoutConfiguration {
            // verwacht — geen bevestigd commando, dus expliciete weigering.
        } catch {
            XCTFail("Onverwachte fout: \(error)")
        }
    }

    func test_resumeWorkout_isExplicitlyUnsupported_notGuessed() async {
        let adapter = PM5Adapter(bluetooth: MockBluetoothManager())

        do {
            try await adapter.resumeWorkout()
            XCTFail("Verwachtte PM5Error.unsupportedWorkoutConfiguration")
        } catch PM5Error.unsupportedWorkoutConfiguration {
            // verwacht
        } catch {
            XCTFail("Onverwachte fout: \(error)")
        }
    }

    func test_batteryLevel_isNilNotGuessed() async {
        let adapter = PM5Adapter(bluetooth: MockBluetoothManager())
        let level = await adapter.batteryLevel()
        XCTAssertNil(level)
    }

    func test_metricsStream_isEmptyInThisSprint() async {
        let adapter = PM5Adapter(bluetooth: MockBluetoothManager())
        var iterator = adapter.metricsStream().makeAsyncIterator()
        let first = await iterator.next()
        XCTAssertNil(first)
    }
}
