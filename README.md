# CoachOS Connect (iOS)

Native uitvoeringslaag van het CoachOS-ecosysteem. CoachOS (PWA) blijft het
brein — planning, AI, analyses, beslissingen. CoachOS Connect praat met
hardware: Bluetooth, live metrics, workout-uitvoering, synchronisatie.

> CoachOS denkt. CoachOS Connect voert uit.

## Status: Sprint 6b-1 — Native Supabase-authenticatie

Ketenoverzicht: `iPhone → Supabase Auth (rechtstreeks) → JWT/Keychain →
CoachOS API (Bearer-header, sinds Sprint 6a) → workout/resultaat`.

Deze sprint levert uitsluitend authenticatie. Workout-ophalen/-mapping
(CoachOS' eigen `UniversalWorkout` → Connect's `UniversalWorkout`) en
resultaat-upload volgen in 6b-2/6b-3.

### Wat is er gebouwd (cumulatief t/m Sprint 6b-1)

**Sprint 1 t/m 5b** — zie eerdere secties hieronder/changelog: fundament,
generieke Bluetooth-laag, device discovery, PM5/CSAFE-encoding + adapter.

**Sprint 6a (backend, `coachOS`-repo, apart van deze repository)**
- Gedeelde `getAuthenticatedUser()`-helper: Bearer-token eerst, dan
  cookie — geen tweede auth-systeem
- `coachos_connect` toegevoegd aan de Source Priority Policy
  (prioriteit 110, boven `concept2`s 100)

**Sprint 6b-1 — Native Supabase-authenticatie (nieuw, deze repository)**
- `SupabaseAuthClient`: rechtstreeks tegen Supabase's Auth-REST-API,
  geen SDK-dependency
- `KeychainTokenStore`: sessieopslag via de iOS Keychain
- `RemoteAuthRepository` herschreven: geen nep-CoachOS-auth-endpoint
  meer
- Eerste tests voor de Data-laag (`CoachOSConnectDataTests`)

### Wat hier bewust nog niet in zit
- CoachOS-workout ophalen/mappen naar Connect's `UniversalWorkout` —
  `CoachOSEndpoints` wijst voor workouts/sync nog naar de oude, onjuiste
  `/api/v1/connect/...`-paden (Sprint 6b-2)
- Resultaat-upload naar `activity_sessions` (Sprint 6b-3)
- SPM als informatieve instructie (Optie B) — UI-werk, later
- Google-OAuth vanuit Connect (alleen e-mail/wachtwoord nu)
- Live metrics (Sprint 8), workoutresultaat via GET-commando's (Sprint 7)

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
