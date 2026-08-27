# CoachOS Connect (iOS)

Native uitvoeringslaag van het CoachOS-ecosysteem. CoachOS (PWA) blijft het
brein — planning, AI, analyses, beslissingen. CoachOS Connect praat met
hardware: Bluetooth, live metrics, workout-uitvoering, synchronisatie.

> CoachOS denkt. CoachOS Connect voert uit.

## Status: Sprint 1 — Fundament (architectuur) + patch

Sprint 1 levert de volledige projectstructuur, Clean Architecture, werkende
Dependency Injection en het Device Layer-protocol. **Er zit in deze sprint
bewust geen enkele hardware-implementatie**: geen Bluetooth, geen PM5, geen
fabrikant-SDK, geen audio coach, geen verwerking van live metrics. Eerst de
lege stekkerdoos, daarna de apparaten.

### Wat is er gebouwd
- Swift Package met vier modules: `CoachOSConnectCore`, `CoachOSConnectDeviceLayer`, `CoachOSConnectData`, `CoachOSConnectDI`
- Clean Architecture: Domain (protocollen, modellen, use cases) kent geen implementatiedetails
- `DeviceAdapterProtocol` (volledig `async throws`) — de universele interface die elke toekomstige fabrikant-adapter implementeert
- `DeviceState` + `DeviceStateMachine` — volledige levenscyclus (scanning → connecting → connected → workoutLoaded → running ⇄ paused → finished → syncing → error) met expliciet toegestane transities
- Capability-systeem (`DeviceCapability`) — apparaten worden bevraagd op vaardigheid, nooit op merknaam
- `DeviceLayer` + `DeviceAdapterRegistry` — coördinatiepunt boven alle adapters, registratie via fabrieksfuncties, geen naam-gebaseerde branching
- `UniversalWorkout` / `WorkoutBlock` (`.step` / `.repeatGroup`) / `WorkoutTarget` — hardware- én sport-onafhankelijk trainingsmodel, met `expandedSteps` voor adapters die geen herhalingsstructuur hoeven te begrijpen
- Gestandaardiseerd metrics-model: `LiveMetricSample` / `LiveMetricsBatch` / `MetricType` — één vorm voor elk apparaat, apparaat vult alleen in wat het heeft
- Repository-protocollen + implementaties: workouts, devices, sync, auth
- `APIClient` (generieke HTTP-laag, geversioneerd onder `/api/v1/connect/...`) en `FileLocalStorage` (offline-first cache)
- Lichtgewicht `DIContainer` zonder externe dependencies
- Minimale SwiftUI-shell (`App/`) die de volledige dependency graph aantoonbaar laat werken
- Unit tests die aantonen dat de Domain-laag én de state machine zonder UI of hardware testbaar zijn

### Wat hier bewust nog niet in zit
- Bluetooth / BLE-communicatie
- PM5- of andere fabrikant-adapters
- Live metrics-verwerking (alleen het datamodel/protocol staat vast)
- Audio Coach / Haptic Engine
- Echte backend-koppeling (endpoints zijn gedefinieerd, nog niet tegen een live contract getest)

## Projectstructuur

```
coachos-connect-ios/
├── Package.swift
├── Sources/
│   ├── CoachOSConnectCore/        Domain: modellen, protocollen, use cases, errors
│   ├── CoachOSConnectDeviceLayer/ Device Layer: registry + coördinatie (nog geen adapters)
│   ├── CoachOSConnectData/        Repository-implementaties, API client, lokale opslag
│   └── CoachOSConnectDI/          DIContainer + AppAssembly (enige plek die alles koppelt)
├── App/                           SwiftUI-shell — zie "Xcode opzetten" hieronder
├── Tests/CoachOSConnectCoreTests/
└── docs/
    └── changelog.md
```

## Xcode opzetten (eenmalig, op een Mac)

Dit is een Swift Package, geen `.xcodeproj`. Reden: een `.xcodeproj` is een
XML/binair projectbestand dat Xcode zelf genereert; dat buiten Xcode om
handmatig opbouwen is foutgevoelig. In plaats daarvan:

1. Nieuw Xcode-project → App → SwiftUI, taal Swift, naam bijv. `CoachOSConnect`.
2. File → Add Package Dependencies → Add Local... → wijs naar de root van deze repo (waar `Package.swift` staat).
3. Voeg alle vier de library-targets toe aan het App-target.
4. Vervang de gegenereerde `ContentView.swift`/`App.swift` door de bestanden uit `App/` in deze repo.
5. Neem de sleutels uit `App/Info-template.plist` over in het Info.plist van het App-target zodra Bluetooth-sprints starten (nu nog niet nodig).
6. Build & run.

## Architectuurprincipes (blijven gelden in elke volgende sprint)

1. CoachOS blijft het brein; Connect voert uit.
2. Geen sportlogica in de Device Layer.
3. Elke fabrikant krijgt een eigen `DeviceAdapterProtocol`-implementatie; bestaande code wijzigt niet.
4. Apparaten worden bevraagd op capability, nooit op merk/model in aanroepcode.
5. Offline-first: lokale cache eerst, netwerk als aanvulling.
6. Geen externe dependencies tenzij noodzakelijk.
7. UI kent alleen use cases en Core-protocollen, nooit concrete Data-implementaties.

## Volgende sprints (uit de architectuurvisie)

- Sprint 2 — Authenticatie (koppeling aan echte CoachOS-auth)
- Sprint 3 — Generieke Bluetooth Manager
- Sprint 4 — Device discovery / device UI
- Sprint 5 — PM5 Adapter (eerste concrete implementatie)
- Sprint 6 — Live CoachOS API-integratie
- Sprint 7 — Workout Sync
- Sprint 8 — Live Metrics
- Sprint 9 — Workout Player
- Sprint 10 — Audio Coach + Haptics
