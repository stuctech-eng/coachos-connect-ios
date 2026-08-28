# CoachOS Connect (iOS)

Native uitvoeringslaag van het CoachOS-ecosysteem. CoachOS (PWA) blijft het
brein — planning, AI, analyses, beslissingen. CoachOS Connect praat met
hardware: Bluetooth, live metrics, workout-uitvoering, synchronisatie.

> CoachOS denkt. CoachOS Connect voert uit.

## Status: Sprint 6b-3 — Resultaat-upload (Connect-kant)

Sluit de terugweg: `PM5 → Connect → lokale wachtrij → CoachOS →
activity_sessions`. Beide richtingen van de keten staan nu: heen
(Sprint 6b-2) en terug (deze sprint).

**Architectuurbeslissing:** Swift Connect (`CoachOSConnectPM5`) is de
enige runtime PM5/CSAFE-implementatie. Een tweede, onafhankelijk op
CoachOS aangetroffen TypeScript-implementatie is gedeprecieerd
(niet verwijderd — bewaard als validatiemateriaal, zie changelog).

### Wat is er gebouwd (cumulatief t/m Sprint 6b-3)

**Sprint 1 t/m 6b-2** — fundament, Bluetooth-laag, device discovery,
PM5/CSAFE, backend-auth, native auth, workout ophalen + mapping.

**Sprint 6b-3 — Resultaat-upload (nieuw)**
- `ConnectWorkoutResultPayload`: exacte spiegel van het bevestigde
  backend-schema
- `ConnectWorkoutResultBuilder`: pure, testbare payload/`SyncItem`-builder
- `CoachOSEndpoints.workoutResult(body:)`, `LocalSyncRepository`
  herschreven om er daadwerkelijk naartoe te versturen
- `SyncItem.payload: Data` (Core) — het ontbrekende stuk om de wachtrij
  ooit iets zinnigs te kunnen versturen

### Wat hier bewust nog niet in zit
- Koppeling aan een echte trainingssessie — wacht op Sprint 9 (Workout Player)
- Echte `totals`/`intervals`-waarden — wacht op Sprint 8 (live metrics)
- `liveMetricsSession`-sync — geen bevestigd endpoint
- Continue (niet-interval) hoofdblokken zonder rust — bekend gat sinds 6b-2

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
3. Voeg alle zeven de library-targets toe aan het App-target.
4. Vervang de gegenereerde `ContentView.swift`/`App.swift` door de bestanden uit `App/` in deze repo.
5. Neem de sleutels uit `App/Info-template.plist` over in het Info.plist van het App-target — vanaf nu relevant, want `CoachOSConnectBluetooth` gebruikt CoreBluetooth.
6. Build & run.

**Vóór stap 6, verplicht:** vervang `VUL_HIER_DE_ECHTE_PUBLISHABLE_KEY_IN`
in `App/CoachOSConnectApp.swift` (en de `#Preview` in `App/RootView.swift`)
door de echte Supabase publishable key uit het CoachOS Supabase-
dashboard (Project Settings → API). Zonder deze wijziging faalt elke
aanmeldpoging met een duidelijke serverfout.

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
