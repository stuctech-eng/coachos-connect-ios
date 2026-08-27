# CoachOS Connect (iOS)

Native uitvoeringslaag van het CoachOS-ecosysteem. CoachOS (PWA) blijft het
brein — planning, AI, analyses, beslissingen. CoachOS Connect praat met
hardware: Bluetooth, live metrics, workout-uitvoering, synchronisatie.

> CoachOS denkt. CoachOS Connect voert uit.

## Status: Sprint 4 — Device Discovery / UX

Ketenoverzicht: `CoachOS PWA → API/UniversalWorkout → CoachOS Connect →
Bluetooth Manager → Device Discovery/UX → BLE Transport → CSAFE Transport
(Sprint 5) → PM5 Adapter (Sprint 5) → Concept2 PM5`.

Deze sprint levert een generiek "apparaten in de buurt"-scherm bovenop de
Bluetooth-laag uit Sprint 3. **Nog steeds geen PM5-kennis** — apparaten
worden getoond zoals de Bluetooth-laag ze aanlevert, niet herkend.

### Wat is er gebouwd (cumulatief t/m Sprint 4)

**Sprint 1 + patch — Fundament**
- Swift Package, Clean Architecture, `DIContainer`/`AppAssembly`
- `DeviceAdapterProtocol` (async), `DeviceState`/`DeviceStateMachine`
- `UniversalWorkout`/`WorkoutBlock`/`RepeatGroup`, capability-systeem
- Repository-implementaties, `APIClient` (`/api/v1/connect/...`), `FileLocalStorage`
- Minimale SwiftUI-shell, tests

**Sprint 3 — Generieke Bluetooth Manager**
- Module `CoachOSConnectBluetooth`: `BluetoothManagerProtocol`, `CoreBluetoothManager`, `BluetoothConnectionState`/`BluetoothStateMachine`, `MockBluetoothManager`
- Bevestigd gebouwd en getest door een echte Apple-toolchain via GitHub Actions CI (macOS-runner)

**Sprint 4 — Device Discovery / UX (nieuw)**
- Module `CoachOSConnectDeviceDiscovery`: `DiscoveredDeviceList` (pure merge-/sorteerlogica), `DeviceDiscoveryController` (`@MainActor` `ObservableObject`)
- `App/DevicesView.swift`: scan-UI, apparatenlijst, verbind-/verbreekknoppen
- Tests via de Sprint 3 `MockBluetoothManager` — geen hardware nodig

### Wat hier bewust nog niet in zit
- PM5- of andere fabrikant-adapters, CSAFE-commando's, Concept2-UUID's
- Koppeling tussen een ontdekt BLE-apparaat en een `DeviceDescriptor`/adapter uit de Device Layer
- Live metrics-verwerking, Audio Coach, Haptic Engine
- Echte backend-koppeling tegen een live CoachOS-contract

## Projectstructuur

```
coachos-connect-ios/
├── Package.swift
├── Sources/
│   ├── CoachOSConnectCore/        Domain: modellen, protocollen, use cases, errors
│   ├── CoachOSConnectBluetooth/   Generieke BLE-laag (CoreBluetooth), geen fabrikantkennis
│   ├── CoachOSConnectDeviceDiscovery/ Discovery/UX-presentatielaag bovenop Bluetooth
│   ├── CoachOSConnectDeviceLayer/ Device Layer: registry + coördinatie (nog geen adapters)
│   ├── CoachOSConnectData/        Repository-implementaties, API client, lokale opslag
│   └── CoachOSConnectDI/          DIContainer + AppAssembly (enige plek die alles koppelt)
├── App/                           SwiftUI-shell — zie "Xcode opzetten" hieronder
├── Tests/
│   ├── CoachOSConnectCoreTests/
│   ├── CoachOSConnectBluetoothTests/
│   └── CoachOSConnectDeviceDiscoveryTests/
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

- Sprint 5 — PM5 Adapter + CSAFE (eerste concrete implementatie; onderzoek naar CSAFE-commando's, byte-encoding en open protocolvragen staat vast in de projectcontext)
- Sprint 6 — Live CoachOS API-integratie
- Sprint 7 — Workout Sync
- Sprint 8 — Live Metrics
- Sprint 9 — Workout Player
- Sprint 10 — Audio Coach + Haptics
