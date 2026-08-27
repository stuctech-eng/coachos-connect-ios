# Changelog — CoachOS Connect (iOS)

## Sprint 1 — Patch (architectuurreview)

Naar aanleiding van een review op de eerste Sprint 1-levering. Drie
gaten in de architectuur gedicht, vóórdat Sprint 2 (Bluetooth) start.

**Gewijzigd**
- `DeviceAdapterProtocol.connectionState: DeviceConnectionState` vervangen
  door `state: DeviceState` — volledige levenscyclus-state machine
  (`disconnected`, `scanning`, `connecting`, `connected`, `workoutLoaded`,
  `running`, `paused`, `finished`, `syncing`, `error`), inclusief
  `DeviceStateMachine.canTransition(from:to:)` om ongeldige overgangen
  (bijv. `.workoutLoaded → .paused`) vroeg te kunnen weigeren.
- `UniversalWorkout.steps: [WorkoutStep]` vervangen door
  `blocks: [WorkoutBlock]` (`.step` of `.repeatGroup`) plus nieuw type
  `RepeatGroup`, zodat intervalstructuren (bijv. 5×(4 min werk, 2 min rust))
  als herhaling gemodelleerd worden in plaats van als losse, uitgeschreven
  stappen. Nieuwe computed property `expandedSteps` rolt dit plat uit voor
  adapters die geen herhalingsstructuur hoeven te begrijpen.
- `CoachOSEndpoints` geversioneerd: alle paden nu onder `/api/v1/connect/...`
  in plaats van `/api/connect/...`, zodat een toekomstige v2 van het
  CoachOS-contract naast v1 kan bestaan.

**Niet gewijzigd (bleek bij review al aanwezig)**
- Protocol was al volledig `async throws`.
- Metrics waren al gestandaardiseerd (`LiveMetricSample`/`LiveMetricsBatch`/`MetricType`), niet per apparaat.
- Adapter-registratie liep al via `DeviceAdapterRegistry`/`DeviceLayer.register(_:for:)`, geen naam-gebaseerde branching.

---

## Sprint 1 — Fundament (architectuur)

**Toegevoegd**
- Swift Package-structuur: `CoachOSConnectCore`, `CoachOSConnectDeviceLayer`, `CoachOSConnectData`, `CoachOSConnectDI`
- `DeviceAdapterProtocol`: universele hardware-interface (connect, disconnect, sendWorkout, start/pause/resume/stop, metricsStream, sync, batteryLevel)
- Capability-systeem: `DeviceCapability`, `DeviceDescriptor`, `DeviceConnectionState`
- `DeviceLayer` + `DeviceAdapterRegistry`: coördinatie boven adapters, capability-gebaseerde selectie
- `UniversalWorkout`, `WorkoutStep`, `WorkoutTarget`, `WorkoutDuration`, `WorkoutSport`: hardware-onafhankelijk trainingsmodel
- `LiveMetricSample` / `LiveMetricsBatch`: universeel metrics-datamodel (geen verwerking)
- Repository-protocollen: `WorkoutRepositoryProtocol`, `DeviceRepositoryProtocol`, `SyncRepositoryProtocol`, `AuthRepositoryProtocol`
- Repository-implementaties: `RemoteWorkoutRepository` (offline-first via `WorkoutCache`), `LocalDeviceRepository`, `LocalSyncRepository`, `RemoteAuthRepository`
- `APIClient` + `APIEndpoint` + `CoachOSEndpoints`: generieke, endpoint-gedefinieerde HTTP-laag
- `FileLocalStorage`: bestandsgebaseerde lokale opslag achter `LocalStorageProtocol`
- `DIContainer` + `AppAssembly`: lichtgewicht DI zonder externe frameworks, enige koppelpunt tussen protocol en implementatie
- `App/CoachOSConnectApp.swift` + `App/RootView.swift`: minimale SwiftUI-shell die de dependency graph aantoonbaar laat werken
- Unit tests (`UniversalWorkoutTests`): Codable-round-trip + use-case-gedrag zonder UI/hardware

**Bewust niet toegevoegd**
- Bluetooth/BLE-implementatie
- PM5- of andere fabrikant-adapters (`Sources/CoachOSConnectDeviceLayer/Adapters/` is leeg, zie README daarin)
- Live metrics-verwerking/interpretatie
- Audio Coach, Haptic Engine
- `.xcodeproj` (bewust een Swift Package; zie hoofd-README "Xcode opzetten")

**Open punten voor volgende sprint**
- `baseURL` in `CoachOSConnectApp.swift` is hardcoded naar `coach-os-tau.vercel.app`; moet naar omgevingsconfiguratie (dev/staging/prod)
- Backend-endpoints in `CoachOSEndpoints` zijn nog niet getoetst aan een live CoachOS-contract
- Geen enkele Bluetooth-permissie actief; `Info-template.plist` staat klaar voor wanneer dat relevant wordt
