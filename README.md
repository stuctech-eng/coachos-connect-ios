# CoachOS Connect (iOS)

Native uitvoeringslaag van het CoachOS-ecosysteem. CoachOS (PWA) blijft het
brein — planning, AI, analyses, beslissingen. CoachOS Connect praat met
hardware: Bluetooth, live metrics, workout-uitvoering, synchronisatie.

> CoachOS denkt. CoachOS Connect voert uit.

## Status: Sprint 7a/7b — PM5 Rowing Service discovery + General Status-decoder

Eerste stap richting de eerste fysieke PM5-test. Alleen `0x0031`
(General Status): discovery, subscriptie, ruwe-bytes-logging, en een
pure decoder. `0x0032`/`0x0033` bewust nog niet — zie het
Sprint 7-onderzoeksrapport voor de reden (tegenstrijdigheid in de
officiële spec, eerst empirisch te bevestigen).

### Wat is er gebouwd (cumulatief, actuele stand)

**Sprint 1 t/m continue-hoofdblok-fix** — volledige softwareketen, beide
richtingen (CoachOS ↔ Connect ↔ PM5-programmering), CI groen.

**Sprint 7a/7b — Rowing Service discovery + General Status (nieuw)**
- `PM5RowingStatusMonitor`: Rowing Service discovery, `0x0031`-
  subscriptie, ruwe-bytes-logging — standalone, nog niet aan
  `PM5Adapter` gekoppeld
- `PM5GeneralStatusDecoder` + `PM5GeneralStatus`: pure, geteste decoder
  voor de 19-byte General Status-characteristic

### Wat hier bewust nog niet in zit
- `0x0032`/`0x0033` (Additional Status 1/2) — Sprint 7c, na empirische
  bevestiging van de daadwerkelijke bytelengte
- Koppeling aan `PM5Adapter.metricsStream()` — Sprint 8
- **De eerste fysieke PM5-hardwaretest zelf** — alles hierboven is
  softwarematig bewezen (CI groen, decoder tegen een handmatig
  opgebouwde testvector), niet fysiek gevalideerd. Dat is precies waar
  dit voor gebouwd is: de kleinst mogelijke, zinvolle eerste stap.

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
3. Voeg alle acht de library-targets toe aan het App-target.
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
