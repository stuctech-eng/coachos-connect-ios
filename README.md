# CoachOS Connect (iOS)

Native uitvoeringslaag van het CoachOS-ecosysteem. CoachOS (PWA) blijft het
brein — planning, AI, analyses, beslissingen. CoachOS Connect praat met
hardware: Bluetooth, live metrics, workout-uitvoering, synchronisatie.

> CoachOS denkt. CoachOS Connect voert uit.

## Status: Sprint 3 — Generieke Bluetooth Manager

Ketenoverzicht: `CoachOS PWA → API/UniversalWorkout → CoachOS Connect →
Bluetooth Manager → BLE Transport → CSAFE Transport (Sprint 5) → PM5
Adapter (Sprint 5) → Concept2 PM5`.

Deze sprint levert uitsluitend de generieke BLE-laag. **Geen PM5-kennis,
geen CSAFE, geen Concept2-specifieke UUID's** — die komen pas in Sprint 5.

### Wat is er gebouwd (cumulatief t/m Sprint 3)

**Sprint 1 + patch — Fundament**
- Swift Package, Clean Architecture, `DIContainer`/`AppAssembly`
- `DeviceAdapterProtocol` (async), `DeviceState`/`DeviceStateMachine`
- `UniversalWorkout`/`WorkoutBlock`/`RepeatGroup`, capability-systeem
- Repository-implementaties, `APIClient` (`/api/v1/connect/...`), `FileLocalStorage`
- Minimale SwiftUI-shell, tests

**Sprint 3 — Generieke Bluetooth Manager (nieuw)**
- Nieuwe module `CoachOSConnectBluetooth`, geen dependencies (ook niet op Core)
- `BluetoothManagerProtocol`: scan, discovery, connect/disconnect, reconnect-beleid, verbindingsstatus, service-/characteristic-discovery, read/write/subscribe
- `BluetoothConnectionState` + `BluetoothStateMachine` — eigen, kleinere state machine dan `DeviceState`, bewust gescheiden
- `CoreBluetoothManager` — enige plek met `import CoreBluetooth`
- `MockBluetoothManager` — testdubbel zonder hardware, herbruikbaar in Sprint 5
- `AppAssembly` registreert de Bluetooth Manager als infrastructuur, nog aan geen adapter gekoppeld

### Wat hier bewust nog niet in zit
- PM5- of andere fabrikant-adapters, CSAFE-commando's, Concept2-UUID's
- Live metrics-verwerking
- Audio Coach / Haptic Engine
- Echte backend-koppeling tegen een live CoachOS-contract
- Compilatie/tests tegen een echte CoreBluetooth-runtime (vereist Xcode/simulator of fysiek toestel)

## Projectstructuur

```
coachos-connect-ios/
├── Package.swift
├── Sources/
│   ├── CoachOSConnectCore/        Domain: modellen, protocollen, use cases, errors
│   ├── CoachOSConnectBluetooth/   Generieke BLE-laag (CoreBluetooth), geen fabrikantkennis
│   ├── CoachOSConnectDeviceLayer/ Device Layer: registry + coördinatie (nog geen adapters)
│   ├── CoachOSConnectData/        Repository-implementaties, API client, lokale opslag
│   └── CoachOSConnectDI/          DIContainer + AppAssembly (enige plek die alles koppelt)
├── App/                           SwiftUI-shell — zie "Xcode opzetten" hieronder
├── Tests/
│   ├── CoachOSConnectCoreTests/
│   └── CoachOSConnectBluetoothTests/
└── docs/
    └── changelog.md
```

## Xcode opzetten (eenmalig, op een Mac)

Dit is een Swift Package, geen `.xcodeproj`. Reden: een `.xcodeproj` is een
XML/binair projectbestand dat Xcode zelf genereert; dat buiten Xcode om
handmatig opbouwen is foutgevoelig. In plaats daarvan:

1. Nieuw Xcode-project → App → SwiftUI, taal Swift, naam bijv. `CoachOSConnect`.
2. File → Add Package Dependencies → Add Local... → wijs naar de root van deze repo (waar `Package.swift` staat).
3. Voeg alle vijf de library-targets toe aan het App-target.
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

- Sprint 4 — Device discovery / device UI (bovenop `BluetoothManagerProtocol`, nog geen PM5-kennis)
- Sprint 5 — PM5 Adapter + CSAFE (eerste concrete implementatie; onderzoek naar CSAFE-commando's, byte-encoding en open protocolvragen staat vast in de projectcontext)
- Sprint 6 — Live CoachOS API-integratie
- Sprint 7 — Workout Sync
- Sprint 8 — Live Metrics
- Sprint 9 — Workout Player
- Sprint 10 — Audio Coach + Haptics
