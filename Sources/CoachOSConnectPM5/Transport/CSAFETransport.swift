import Foundation
import CoachOSConnectBluetooth

/// Koppelt CSAFE-framing aan de generieke `BluetoothManagerProtocol` uit
/// Sprint 3. Dit is de enige plek in `CoachOSConnectPM5` die weet over BLE
/// — alle CSAFE-byteencoding (Sprint 5a) blijft daar volledig onafhankelijk
/// van.
///
/// Verstuurt naar de C2 PM Receive Characteristic (0x0021, WRITE) en
/// ontvangt via de C2 PM Transmit Characteristic (0x0022) — bevestigd via
/// de officiële Concept2 BLE-interfacedefinitie. Zoals daar gedocumenteerd:
/// de officiële tabel vermeldt "READ" voor 0x0022, maar in de praktijk
/// (bevestigd via meerdere ontwikkelaars-forumdiscussies) werkt dit via
/// notify-abonnement, niet via losse reads — zo is het hier geïmplementeerd.
public actor CSAFETransport {
    private let bluetooth: BluetoothManagerProtocol
    private let deviceId: UUID

    private let receiveCharacteristic = BLECharacteristicAddress(
        serviceUUID: PM5BLEConstants.controlServiceUUID,
        characteristicUUID: PM5BLEConstants.controlReceiveCharacteristicUUID
    )
    private let transmitCharacteristic = BLECharacteristicAddress(
        serviceUUID: PM5BLEConstants.controlServiceUUID,
        characteristicUUID: PM5BLEConstants.controlTransmitCharacteristicUUID
    )

    public init(bluetooth: BluetoothManagerProtocol, deviceId: UUID) {
        self.bluetooth = bluetooth
        self.deviceId = deviceId
    }

    /// Verstuurt kant-en-klare, reeds geëncodeerde CSAFE-framebytes (van
    /// `CSAFEFrame.encode`/`PM5Frame.encode`/`PM5ControlCommand.frame`).
    public func send(_ frame: [UInt8]) async throws {
        try await bluetooth.write(Data(frame), to: receiveCharacteristic, on: deviceId, expectingResponse: false)
    }

    /// Stream van ontvangen, reeds gedecodeerde CSAFE-frame-inhoud (dus ná
    /// verwerking van start/stop/checksum/stuffing). Frames die niet aan de
    /// checksum voldoen, of anderszins niet als geldig CSAFE-frame te
    /// ontleden zijn, worden overgeslagen — nooit als geldige data
    /// doorgegeven.
    ///
    /// BELANGRIJK voor de aanroeper: roep dit aan en start de consumptie
    /// ervan VÓÓRDAT `send(_:)` voor het eerst wordt aangeroepen. Dezelfde
    /// abonneer-vóór-actie-discipline als bij `DeviceDiscoveryController`
    /// (Sprint 4): het onderliggende `subscribe`-abonnement moet al actief
    /// zijn vóórdat de PM5 iets terug kan sturen, anders kan een vroege
    /// respons gemist worden.
    public func responseStream() async throws -> AsyncStream<[UInt8]> {
        let rawStream = try await bluetooth.subscribe(to: transmitCharacteristic, on: deviceId)
        return AsyncStream { continuation in
            let task = Task {
                for await data in rawStream {
                    if let content = try? CSAFEFrame.decode([UInt8](data)) {
                        continuation.yield(content)
                    }
                    // Frames die niet decoderen (bijv. door de bekende,
                    // gedocumenteerde PM5-over-BLE-CSAFE-onregelmatigheden,
                    // zie PM5Adapter) worden bewust stilzwijgend overgeslagen
                    // hier; de aanroeper ziet alleen geldige, geverifieerde
                    // inhoud.
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
