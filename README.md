# CoachOS Connect (iOS)

Native uitvoeringslaag van het CoachOS-ecosysteem. CoachOS (PWA) blijft het
brein — planning, AI, analyses, beslissingen. CoachOS Connect praat met
hardware: Bluetooth, live metrics, workout-uitvoering, synchronisatie.

> CoachOS denkt. CoachOS Connect voert uit.

## Status: Sprint 5a — PM5/CSAFE-encoding (pure, nog geen BLE)

Ketenoverzicht: `CoachOS PWA → API/UniversalWorkout → CoachOS Connect →
Bluetooth Manager → Device Discovery/UX → BLE Transport (Sprint 5b) →
CSAFE Transport (Sprint 5b) → PM5 Adapter (Sprint 5b) → Concept2 PM5`.

Deze sprint levert de PM5/CSAFE-**encoding**-laag: hoe je bytes bouwt die
de PM5 begrijpt. Nog geen BLE-verbinding — dat is Sprint 5b. Alle
protocoldetails zijn geverifieerd tegen officiële Concept2-documentatie
en/of werkende open-sourcecode vóór implementatie (zie changelog voor het
volledige onderzoeksverslag).

### Wat is er gebouwd (cumulatief t/m Sprint 5a)

**Sprint 1 + patch — Fundament**
- Swift Package, Clean Architecture, `DIContainer`/`AppAssembly`
- `DeviceAdapterProtocol` (async), `DeviceState`/`DeviceStateMachine`
- `UniversalWorkout`/`WorkoutBlock`/`RepeatGroup`, capability-systeem
- Repository-implementaties, `APIClient` (`/api/v1/connect/...`), `FileLocalStorage`
- Minimale SwiftUI-shell, tests

**Sprint 3 — Generieke Bluetooth Manager**
- Module `CoachOSConnectBluetooth`: `BluetoothManagerProtocol`, `CoreBluetoothManager`, `MockBluetoothManager`
- Bevestigd gebouwd en getest door een echte Apple-toolchain via GitHub Actions CI

**Sprint 4 — Device Discovery / UX**
- Module `CoachOSConnectDeviceDiscovery`: `DiscoveredDeviceList`, `DeviceDiscoveryController`
- `App/DevicesView.swift`

**Sprint 5a — PM5/CSAFE-encoding (nieuw)**
- Module `CoachOSConnectPM5`: `CSAFEFrame`/`CSAFEByteStuffing` (framing, geverifieerd tegen echte gevangen frames), `PM5ProprietaryCommand` (de acht bevestigde workoutprogrammeer-commando's), `PM5Frame` (`SETPMCFG_CMD`-wrapper), `PM5WorkoutProgrammer` (`UniversalWorkout` → PM5-intervalblokken voor het bevestigde MVP-geval), `PM5BLEConstants` (GATT-UUID's, nog niet gekoppeld)
- Nog géén BLE-verbinding, nog géén `PM5Adapter`

### Wat hier bewust nog niet in zit
- BLE-transportkoppeling voor PM5 (`CSAFETransport`/`BLETransport`) en een `PM5Adapter` conform `DeviceAdapterProtocol` — Sprint 5b
- Response-/statusframe-decodering, live metrics — latere sprints
- Undefined-rest-workouts, afstandgebaseerde intervallen — expliciet geweigerd, niet gegokt
- Audio Coach / Haptic Engine
- Echte backend-koppeling tegen een live CoachOS-contract

## Projectstructuur

```
coachos-connect-ios/
├── Package.swift
├── Sources/
│   ├── CoachOSConnectCore/        Domain: modellen, protocollen, use cases, errors
│   ├── CoachOSConnectBluetooth/   Generieke BLE-laag (CoreBluetooth), geen fabrikantkennis
│   ├── CoachOSConnectDeviceDiscovery/ Discovery/UX-presentatielaag bovenop Bluetooth
│   ├── CoachOSConnectPM5/         PM5/CSAFE-encoding (Sprint 5a), nog geen BLE-koppeling
│   ├── CoachOSConnectDeviceLayer/ Device Layer: registry + coördinatie (nog geen adapters)
│   ├── CoachOSConnectData/        Repository-implementaties, API client, lokale opslag
│   └── CoachOSConnectDI/          DIContainer + AppAssembly (enige plek die alles koppelt)
├── App/                           SwiftUI-shell — zie "Xcode opzetten" hieronder
├── Tests/
│   ├── CoachOSConnectCoreTests/
│   ├── CoachOSConnectBluetoothTests/
│   ├── CoachOSConnectDeviceDiscoveryTests/
│   └── CoachOSConnectPM5Tests/
└── docs/
    └── changelog.md
```

## Xcode opzetten (eenmalig, op een Mac)

Dit is een Swift Package, geen `.xcodeproj`. Reden: een `.xcodeproj` is een
XML/binair projectbestand dat Xcode zelf genereert; dat buiten Xcode om
handmatig opbouwen is foutgevoelig. In plaats daarvan:

1. Nieuw Xcode-project → App → SwiftUI, taal Swift, naam bijv. `CoachOSConnect`.
2. File → Add Package Dependencies → Add Local... → wijs naar de root van deze repo (waar `Package.swift` staat).
3. Voeg alle zes de library-targets toe aan het App-target.
4. Vervang de gegenereerde `ContentView.swift`/`App.swift` door de bestanden uit `App/` in deze repo.
5. Neem de sleutels uit `App/Info-template.plist` over in het Info.plist van het App-target — vanaf nu relevant, want `CoachOSConnectBluetooth` gebruikt CoreBluetooth.
6. Build & run.

## Architectuurprincipes (blijven gelden in elke volgende sprint)

1. CoachOS blijft het brein; Connect voert uit.
2. Geen sportlogica in de Device Layer, geen fabrikantkennis in de Bluetooth-laag.
3. Elke fabrikant krijgt een eigen `DeviceAdapterProtocol`-implementatie; bestaande code wijzigt niet.
4. Apparaten worden bevraagd op capability, nooit op merk/model in aanroepcode.
5. CSAFE/protocolsemantiek en BLE-transport blijven gescheiden lagen (Sprint 5: `PM5Adapter` bovenop `BluetoothManagerProtocol`, niet erin verweven).
6. Offline-first: lokale cache eerst, netwerk als aanvulling.
7. Geen externe dependencies tenzij noodzakelijk.
8. UI kent alleen use cases en Core-protocollen, nooit concrete Data-/Bluetooth-implementaties.

## Volgende sprints (uit de architectuurvisie)

- Sprint 5b — CSAFE Transport + BLE-koppeling + `PM5Adapter` conform `DeviceAdapterProtocol` (bouwt voort op de encoding-laag uit Sprint 5a)
- Sprint 6 — Live CoachOS API-integratie
- Sprint 7 — Workout Sync
- Sprint 8 — Live Metrics
- Sprint 9 — Workout Player
- Sprint 10 — Audio Coach + Haptics
