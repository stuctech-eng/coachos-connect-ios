# CoachOS Connect (iOS)

Native uitvoeringslaag van het CoachOS-ecosysteem. CoachOS (PWA) blijft het
brein — planning, AI, analyses, beslissingen. CoachOS Connect praat met
hardware: Bluetooth, live metrics, workout-uitvoering, synchronisatie.

> CoachOS denkt. CoachOS Connect voert uit.

## Status: Sprint 5b — CSAFE Transport + BLE-koppeling + PM5Adapter

Ketenoverzicht: `CoachOS PWA → API/UniversalWorkout → CoachOS Connect →
Bluetooth Manager → CSAFE Transport → PM5Adapter → Concept2 PM5`. Voor het
eerst een volledig aanroepbare, in de Device Layer geregistreerde
`DeviceAdapterProtocol`-implementatie.

### Wat is er gebouwd (cumulatief t/m Sprint 5b)

**Sprint 1 + patch — Fundament**
- Swift Package, Clean Architecture, `DIContainer`/`AppAssembly`
- `DeviceAdapterProtocol` (async), `DeviceState`/`DeviceStateMachine`
- `UniversalWorkout`/`WorkoutBlock`/`RepeatGroup`, capability-systeem
- Repository-implementaties, `APIClient` (`/api/v1/connect/...`), `FileLocalStorage`
- Minimale SwiftUI-shell, tests

**Sprint 3 — Generieke Bluetooth Manager**
- Module `CoachOSConnectBluetooth`: `BluetoothManagerProtocol`, `CoreBluetoothManager`, `MockBluetoothManager`

**Sprint 4 — Device Discovery / UX**
- Module `CoachOSConnectDeviceDiscovery`, `App/DevicesView.swift`

**Sprint 5a — PM5/CSAFE-encoding**
- Module `CoachOSConnectPM5`: `CSAFEFrame`, `PM5ProprietaryCommand`, `PM5Frame`, `PM5WorkoutProgrammer`, `PM5BLEConstants`

**Sprint 5b — CSAFE Transport + BLE-koppeling + PM5Adapter (nieuw)**
- `CSAFETransport`: koppelt CSAFE-framing aan `BluetoothManagerProtocol`
- `PM5ControlCommand`: bevestigde `GOINUSE`/`GOFINISHED`-statuscommando's
- `PM5Adapter`: volledige, geregistreerde `DeviceAdapterProtocol`-implementatie
- `AppAssembly`: PM5-registratie bij de `DeviceLayer` (placeholder sinds Sprint 1 ingevuld)

### Wat hier bewust nog niet in zit
- `pauseWorkout()`/`resumeWorkout()` — geen bevestigd commando, expliciet geweigerd
- Live metrics-decodering (C2 Rowing Service) — Sprint 8
- Workoutresultaat ophalen na afloop — Sprint 7
- Keuze tussen meerdere gelijktijdig zichtbare PM5's
- Hardwarevalidatie van `startWorkout()`/`stopWorkout()` — geïmplementeerd volgens bevestigde commando's, nog niet tegen een fysieke PM5 getest
- Audio Coach / Haptic Engine, echte backend-koppeling

## Projectstructuur

```
coachos-connect-ios/
├── Package.swift
├── Sources/
│   ├── CoachOSConnectCore/        Domain: modellen, protocollen, use cases, errors
│   ├── CoachOSConnectBluetooth/   Generieke BLE-laag (CoreBluetooth), geen fabrikantkennis
│   ├── CoachOSConnectDeviceDiscovery/ Discovery/UX-presentatielaag bovenop Bluetooth
│   ├── CoachOSConnectPM5/         PM5/CSAFE-encoding + BLE-transport + PM5Adapter
│   ├── CoachOSConnectDeviceLayer/ Device Layer: registry + coördinatie (PM5Adapter geregistreerd)
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

- Sprint 6 — Live CoachOS API-integratie
- Sprint 7 — Workout Sync (incl. resultaatophaling via GET-commando's)
- Sprint 8 — Live Metrics (C2 Rowing Service-decodering)
- Sprint 9 — Workout Player
- Sprint 10 — Audio Coach + Haptics
