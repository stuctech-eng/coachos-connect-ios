import XCTest
import CoachOSConnectBluetooth
@testable import CoachOSConnectPM5

final class CSAFETransportTests: XCTestCase {

    func test_send_writesEncodedFrameToReceiveCharacteristic() async throws {
        let mock = MockBluetoothManager()
        let deviceId = UUID()
        let transport = CSAFETransport(bluetooth: mock, deviceId: deviceId)

        let frame = PM5ControlCommand.goInUse.frame
        try await transport.send(frame)

        XCTAssertEqual(mock.writtenValues.count, 1)
        let written = mock.writtenValues[0]
        XCTAssertEqual(written.deviceId, deviceId)
        XCTAssertEqual(written.address.serviceUUID, PM5BLEConstants.controlServiceUUID)
        XCTAssertEqual(written.address.characteristicUUID, PM5BLEConstants.controlReceiveCharacteristicUUID)
        XCTAssertEqual([UInt8](written.data), frame)
    }

    func test_responseStream_decodesValidCSAFEFrameFromTransmitCharacteristic() async throws {
        let mock = MockBluetoothManager()
        let deviceId = UUID()
        let transport = CSAFETransport(bluetooth: mock, deviceId: deviceId)

        let stream = try await transport.responseStream()
        var iterator = stream.makeAsyncIterator()

        let transmitAddress = BLECharacteristicAddress(
            serviceUUID: PM5BLEConstants.controlServiceUUID,
            characteristicUUID: PM5BLEConstants.controlTransmitCharacteristicUUID
        )
        // Echte gevangen CSAFE_GETSERIAL-response, zie CSAFEFrameTests.
        let rawFrame: [UInt8] = [0xF1, 0x81, 0x94, 0x09, 0x34, 0x33, 0x30, 0x31, 0x30, 0x39, 0x31, 0x39, 0x39, 0x22, 0xF2]
        mock.simulateNotification(Data(rawFrame), for: transmitAddress, on: deviceId)

        let content = await iterator.next()
        XCTAssertEqual(content, [0x81, 0x94, 0x09, 0x34, 0x33, 0x30, 0x31, 0x30, 0x39, 0x31, 0x39, 0x39])
    }

    func test_responseStream_skipsInvalidFramesWithoutCrashing() async throws {
        let mock = MockBluetoothManager()
        let deviceId = UUID()
        let transport = CSAFETransport(bluetooth: mock, deviceId: deviceId)

        let stream = try await transport.responseStream()
        var iterator = stream.makeAsyncIterator()

        let transmitAddress = BLECharacteristicAddress(
            serviceUUID: PM5BLEConstants.controlServiceUUID,
            characteristicUUID: PM5BLEConstants.controlTransmitCharacteristicUUID
        )
        // Ongeldig frame (verkeerde checksum), gevolgd door een geldig frame.
        mock.simulateNotification(Data([0xF1, 0x94, 0x00, 0xF2]), for: transmitAddress, on: deviceId)
        mock.simulateNotification(Data([0xF1, 0x94, 0x94, 0xF2]), for: transmitAddress, on: deviceId)

        let content = await iterator.next()
        XCTAssertEqual(content, [0x94])
    }
}
