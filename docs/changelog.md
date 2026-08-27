
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

---

## CI-fix — macOS-platform-ondergrens

Eerste run van `.github/workflows/ios-ci.yml` faalde: `Package.swift`
declareerde alleen `.iOS(.v16)`, geen `.macOS`. Omdat de CI de Swift Package
op de macOS-runner bouwt (geen simulator), viel SwiftPM terug op een oude
standaard macOS-ondergrens van vóór Swift Concurrency. Gevolg:
availability-errors op `AsyncStream`, `CheckedContinuation` en
`withCheckedThrowingContinuation` in `CoachOSConnectBluetooth` (die
allemaal macOS 10.15+ vereisen).

**Gewijzigd**
- `Package.swift`: `.macOS(.v13)` toegevoegd aan `platforms`. Raakt alleen
  hoe SPM zich gedraagt wanneer voor macOS gebouwd wordt (uitsluitend in
  CI) — geen architectuurwijziging, `App/` (de iOS-app) is geen
  SwiftPM-target en blijft ongemoeid.

**Herkomst van de diagnose**
GitHub Copilot's "fix workflow failure"-suggestie (per ongeluk getriggerd)
identificeerde de correcte oorzaak en dezelfde fix, op een aparte branch
(`copilot/fix-swift-package-build-test`, niet gemerged). De diagnose is
geverifieerd door de branch-inhoud direct op te halen en te vergelijken —
functioneel identiek aan deze wijziging. Deze changelog-entry en de
daadwerkelijke merge lopen via de reguliere patch-route, niet via die PR.

---

## CI-fix — async-aanroep binnen XCTAssert-autoclosure

Na de macOS-platformfix kwam de build voorbij het eerdere faalpunt en
compileerde `CoachOSConnectBluetooth` succesvol (bevestigd via de Actions-
log: Xcode 16.4, Apple Swift 6.1.2, target `arm64-apple-macosx14.0`). Nieuwe,
losstaande compilerfout in `BluetoothManagerTests.swift`:

```
error: 'async' call in an autoclosure that does not support concurrency
XCTAssertEqual(await mock.connectionState(for: deviceId), .disconnected)
```

**Oorzaak:** `XCTAssertEqual` neemt zijn argumenten als `@autoclosure () throws -> T`
— niet async. Een `await`-aanroep direct binnen die autoclosure compileert niet.

**Gewijzigd**
- `Tests/CoachOSConnectBluetoothTests/BluetoothManagerTests.swift`:
  `test_mockBluetoothManager_connectUpdatesConnectionState` aangepast — de
  twee `await mock.connectionState(for:)`-aanroepen worden nu eerst in een
  lokale `let` vastgelegd, pas daarna geasserteerd. Geen enkele andere test
  of productiecode aangeraakt; dit was de enige plek in de repository met
  dit patroon.
