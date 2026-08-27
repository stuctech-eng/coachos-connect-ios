
---

## Sprint 3 — Generieke Bluetooth Manager

Kent geen enkel apparaat, geen PM5, geen CSAFE. Uitsluitend generieke
BLE-primitieven, bedoeld om in Sprint 5 door `PM5Adapter` gebruikt te worden
via `BluetoothManagerProtocol` — zonder dat deze module ooit hoeft te
wijzigen wanneer dat gebeurt.

**Toegevoegd**
- Nieuwe module `CoachOSConnectBluetooth` (geen dependencies, ook niet op `CoachOSConnectCore` — volledig zelfstandig herbruikbaar).
- `BluetoothManagerProtocol`: scan, discovery, connect/disconnect, reconnect-beleid, verbindingsstatus (async + stream), service-/characteristic-discovery, read/write/subscribe — volledig `async throws` / `AsyncStream`.
- `BluetoothConnectionState` + `BluetoothStateMachine`: eigen, kleinere state machine dan `DeviceState` uit Core — puur transportniveau, bewust gescheiden (zie architectuurregel in sectie 31/33 van het masterdocument).
- `BluetoothDevice`, `BLECharacteristicAddress`, `BLECharacteristic`, `BLEService`, `BluetoothReconnectPolicy`: generieke datamodellen, geen fabrikant-specifieke UUID's.
- `BluetoothError`: getypeerde foutdomein voor de transportlaag (`bluetoothUnavailable`, `connectionFailed`, `characteristicNotFound`, ...).
- `BluetoothLogging` + `OSBluetoothLogger` / `NoOpBluetoothLogger`: injecteerbare logging via `os.log`, stil in tests.
- `CoreBluetoothManager`: de enige plek in de codebase die `import CoreBluetooth` doet. Wrapt `CBCentralManagerDelegate`/`CBPeripheralDelegate`-callbacks in `async throws`/`AsyncStream`.
- `MockBluetoothManager` (in de hoofdmodule, onder `Testing/`): in-memory testdubbel, herbruikbaar door toekomstige adapter-tests (Sprint 5) zonder hardware.
- Tests: state-machine-transities (geldig/ongeldig) + mock-based tests die aantonen dat consumers tegen het protocol getest kunnen worden zonder BLE-hardware.
- `AppAssembly` registreert `BluetoothManagerProtocol → CoreBluetoothManager` als infrastructuur in de DI-container — nog aan geen enkele adapter gekoppeld.

**Bewust niet toegevoegd**
- PM5-adapter, CSAFE-commando's, Concept2-specifieke UUID's, workout-encoding, PM5-metrics (blijft Sprint 5).
- Multi-subscriber ondersteuning op `discoveredDevicesStream()` — Sprint 3-beperking, gedocumenteerd in `CoreBluetoothManager`; één actieve consument volstaat voor Sprint 4 (device discovery UI).
- Achtergrondmodi zijn nog niet geactiveerd (`Info-template.plist` staat al klaar sinds Sprint 1, moet nu daadwerkelijk in het Xcode-App-target).

**Open punten voor volgende sprint**
- Niet gecompileerd/getest tegen echte CoreBluetooth-runtime (vereist Xcode/simulator of fysiek toestel — niet beschikbaar in deze ontwikkelomgeving).
- `discoverServicesAndCharacteristics` filtert services via CoreBluetooth zelf (`discoverServices(_:)`), maar past het `serviceUUIDs`-filter niet ook toe op de characteristic-discovery-fase — voor Sprint 4 relevant om te verifiëren met een echt apparaat.
- Sprint 4: device discovery UI bovenop deze laag, nog steeds geen PM5-kennis.
