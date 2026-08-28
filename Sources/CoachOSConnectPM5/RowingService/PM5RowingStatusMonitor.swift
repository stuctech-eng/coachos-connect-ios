import Foundation
import CoachOSConnectBluetooth

/// Sprint 7a: ontdekt de C2 Rowing Service, abonneert op General Status
/// (`0x0031`), en geeft de RUWE bytes door — geen decodering hier (dat is
/// `PM5GeneralStatusDecoder`, Sprint 7b). Elke ontvangen notification
/// wordt gelogd (bytelengte + hex-dump), zodat de eerste hardwaretest
/// zonder UI al zichtbaar bewijs oplevert.
///
/// BEWUST NOG NIET GEKOPPELD aan `PM5Adapter`/`metricsStream()` — dat is
/// Sprint 8. Dit is uitsluitend de onderzoeks-/validatielaag voor de
/// eerste fysieke PM5-test, zoals afgesproken (Sprint 7-onderzoeksrapport,
/// 28 augustus 2026): eerst bewijzen dat ruwe bytes daadwerkelijk
/// binnenkomen, pas daarna interpreteren.
///
/// Abonneert bewust vóór het schrijven naar `0x0034` — zelfde discipline
/// als de Sprint 4/5b race-fixes: eerst de stream, dan pas actie die een
/// respons kan triggeren.
public actor PM5RowingStatusMonitor {
    private let bluetooth: BluetoothManagerProtocol
    private let deviceId: UUID
    private let logger: BluetoothLogging

    private let generalStatusCharacteristic = BLECharacteristicAddress(
        serviceUUID: PM5BLEConstants.rowingServiceUUID,
        characteristicUUID: PM5BLEConstants.rowingGeneralStatusCharacteristicUUID
    )
    private let sampleRateCharacteristic = BLECharacteristicAddress(
        serviceUUID: PM5BLEConstants.rowingServiceUUID,
        characteristicUUID: PM5BLEConstants.rowingSampleRateCharacteristicUUID
    )

    public init(bluetooth: BluetoothManagerProtocol, deviceId: UUID, logger: BluetoothLogging = OSBluetoothLogger()) {
        self.bluetooth = bluetooth
        self.deviceId = deviceId
        self.logger = logger
    }

    /// Ontdekt de Rowing Service, abonneert op `0x0031`, en probeert
    /// (best-effort — een mislukte schrijfpoging naar `0x0034` is geen
    /// reden om te stoppen, de PM5 valt dan terug op zijn 500ms-standaard)
    /// de update-frequentie te zetten. Geeft de ruwe, ongedecodeerde
    /// bytes terug.
    public func startMonitoringGeneralStatus(sampleRate: PM5SampleRate = .fiveHundredMs) async throws -> AsyncStream<Data> {
        _ = try await bluetooth.discoverServicesAndCharacteristics(
            for: deviceId,
            serviceUUIDs: [PM5BLEConstants.rowingServiceUUID]
        )

        let rawStream = try await bluetooth.subscribe(to: generalStatusCharacteristic, on: deviceId)

        do {
            try await bluetooth.write(Data([sampleRate.rawValue]), to: sampleRateCharacteristic, on: deviceId, expectingResponse: false)
        } catch {
            logger.log(.warning, "Kon 0x0034 (sample rate) niet zetten — PM5 valt terug op zijn eigen standaard (500ms). Fout: \(error)")
        }

        return AsyncStream { continuation in
            let task = Task {
                for await data in rawStream {
                    if Task.isCancelled { break }
                    let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
                    self.logger.log(.info, "0x0031 General Status ontvangen: \(data.count) bytes — \(hex)")
                    continuation.yield(data)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
