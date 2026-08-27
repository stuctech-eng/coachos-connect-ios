import Foundation

/// Een tijdens scannen ontdekt BLE-apparaat. Bevat uitsluitend generieke
/// advertentie-informatie — geen enkele aanname over wat voor apparaat dit
/// is. Het is aan een hogere laag (in Sprint 5: `PM5Adapter`) om op basis
/// van `advertisedServiceUUIDs` te herkennen of dit een relevant apparaat is.
public struct BluetoothDevice: Identifiable, Equatable, Sendable {
    /// Stabiel binnen één scan-/verbindingssessie op dit toestel. CoreBluetooth
    /// garandeert geen wereldwijd stabiele identifier voor een fysiek apparaat.
    public let id: UUID
    public let name: String?
    public let rssi: Int
    public let advertisedServiceUUIDs: [String]
    public let isConnectable: Bool

    public init(id: UUID, name: String?, rssi: Int, advertisedServiceUUIDs: [String], isConnectable: Bool) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.advertisedServiceUUIDs = advertisedServiceUUIDs
        self.isConnectable = isConnectable
    }
}

/// Generieke identificatie van een characteristic: service-UUID +
/// characteristic-UUID, als strings. Bewust geen `CBUUID`/`CBCharacteristic`
/// hier — die horen bij de CoreBluetooth-implementatie, niet bij de
/// publieke, testbare interface. Bevat geen enkele PM5- of
/// Concept2-specifieke UUID; die worden pas in Sprint 5 door de PM5-adapter
/// aangeleverd.
public struct BLECharacteristicAddress: Hashable, Sendable {
    public let serviceUUID: String
    public let characteristicUUID: String

    public init(serviceUUID: String, characteristicUUID: String) {
        self.serviceUUID = serviceUUID
        self.characteristicUUID = characteristicUUID
    }
}

/// Eigenschappen van een ontdekte characteristic, zoals gerapporteerd door
/// het apparaat zelf (welke operaties het toestaat).
public struct BLECharacteristic: Equatable, Sendable {
    public let address: BLECharacteristicAddress
    public let supportsRead: Bool
    public let supportsWrite: Bool
    public let supportsWriteWithoutResponse: Bool
    public let supportsNotify: Bool

    public init(
        address: BLECharacteristicAddress,
        supportsRead: Bool,
        supportsWrite: Bool,
        supportsWriteWithoutResponse: Bool,
        supportsNotify: Bool
    ) {
        self.address = address
        self.supportsRead = supportsRead
        self.supportsWrite = supportsWrite
        self.supportsWriteWithoutResponse = supportsWriteWithoutResponse
        self.supportsNotify = supportsNotify
    }
}

/// Een ontdekte service met zijn characteristics, resultaat van
/// `BluetoothManagerProtocol.discoverServicesAndCharacteristics`.
public struct BLEService: Equatable, Sendable {
    public let serviceUUID: String
    public let characteristics: [BLECharacteristic]

    public init(serviceUUID: String, characteristics: [BLECharacteristic]) {
        self.serviceUUID = serviceUUID
        self.characteristics = characteristics
    }
}

/// Herverbindingsbeleid per apparaat. Generiek — geen kennis van wélk
/// apparaat dit is. `.automatic` laat de `BluetoothManagerProtocol`-
/// implementatie zelf reconnect-pogingen doen bij onverwacht verlies van
/// verbinding; `.manual` betekent dat de aanroepende laag zelf beslist
/// wanneer opnieuw verbonden wordt.
public enum BluetoothReconnectPolicy: Equatable, Sendable {
    case manual
    case automatic(maxAttempts: Int?)
}
