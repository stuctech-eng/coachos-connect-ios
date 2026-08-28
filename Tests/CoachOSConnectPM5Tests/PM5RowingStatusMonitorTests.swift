import XCTest
import CoachOSConnectBluetooth
@testable import CoachOSConnectPM5

final class PM5RowingStatusMonitorTests: XCTestCase {

    func test_startMonitoring_subscribesToGeneralStatusCharacteristic() async throws {
        let mock = MockBluetoothManager()
        let deviceId = UUID()
        let monitor = PM5RowingStatusMonitor(bluetooth: mock, deviceId: deviceId, logger: NoOpBluetoothLogger())

        let stream = try await monitor.startMonitoringGeneralStatus()
        var iterator = stream.makeAsyncIterator()

        let generalStatusAddress = BLECharacteristicAddress(
            serviceUUID: PM5BLEConstants.rowingServiceUUID,
            characteristicUUID: PM5BLEConstants.rowingGeneralStatusCharacteristicUUID
        )
        let raw = Data([1, 2, 3])
        mock.simulateNotification(raw, for: generalStatusAddress, on: deviceId)

        let received = await iterator.next()
        XCTAssertEqual(received, raw)
    }

    func test_startMonitoring_writesSampleRateToCorrectCharacteristic() async throws {
        let mock = MockBluetoothManager()
        let deviceId = UUID()
        let monitor = PM5RowingStatusMonitor(bluetooth: mock, deviceId: deviceId, logger: NoOpBluetoothLogger())

        _ = try await monitor.startMonitoringGeneralStatus(sampleRate: .oneHundredMs)

        let sampleRateAddress = BLECharacteristicAddress(
            serviceUUID: PM5BLEConstants.rowingServiceUUID,
            characteristicUUID: PM5BLEConstants.rowingSampleRateCharacteristicUUID
        )
        let written = mock.writtenValues.first { $0.address == sampleRateAddress }
        XCTAssertEqual(written?.data, Data([PM5SampleRate.oneHundredMs.rawValue]))
    }

    func test_startMonitoring_sampleRateWriteFailure_doesNotPreventSubscription() async throws {
        // Best-effort: als 0x0034 niet geschreven kan worden, blijft de
        // General Status-subscriptie (het belangrijkste deel) toch werken.
        let mock = MockBluetoothManager()
        let deviceId = UUID()
        mock.stubError(BluetoothError.writeFailed(reason: "test"), for: "write")
        let monitor = PM5RowingStatusMonitor(bluetooth: mock, deviceId: deviceId, logger: NoOpBluetoothLogger())

        let stream = try await monitor.startMonitoringGeneralStatus()
        var iterator = stream.makeAsyncIterator()

        let generalStatusAddress = BLECharacteristicAddress(
            serviceUUID: PM5BLEConstants.rowingServiceUUID,
            characteristicUUID: PM5BLEConstants.rowingGeneralStatusCharacteristicUUID
        )
        mock.simulateNotification(Data([9, 9]), for: generalStatusAddress, on: deviceId)

        let received = await iterator.next()
        XCTAssertEqual(received, Data([9, 9]))
    }
}
