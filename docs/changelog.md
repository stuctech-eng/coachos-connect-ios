
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

---

## Sprint 4 — Device Discovery / UX

Generiek apparaten-scherm bovenop `BluetoothManagerProtocol` uit Sprint 3.
Nog steeds geen PM5-kennis: elk ontdekt apparaat wordt getoond zoals de
Bluetooth-laag het aanlevert (naam, signaalsterkte, verbindbaarheid),
zonder aan te nemen welk apparaat het is.

**Toegevoegd**
- Nieuwe module `CoachOSConnectDeviceDiscovery` (afhankelijk van alleen `CoachOSConnectBluetooth`, geen Core-afhankelijkheid).
- `DiscoveredDeviceList`: pure, synchrone merge-/sorteerlogica — dedupliceert op apparaat-id, sorteert op signaalsterkte. Los van async/Combine, dus zonder mock rechtstreeks testbaar.
- `DeviceDiscoveryController` (`@MainActor`, `ObservableObject`): scan starten/stoppen, ontdekte apparaten publiceren, verbinden/verbreken, verbindingsstatus per apparaat volgen (zowel het directe resultaat van een expliciete `connect`-aanroep als latere, onverwachte statuswijzigingen via de stream).
- `App/DevicesView.swift`: dunne SwiftUI-lijst bovenop de controller — scanknop, apparatenlijst met signaalsterkte en verbind-/verbreekstatus.
- `App/RootView.swift`: navigatielink naar het apparaten-scherm toegevoegd.
- Tests (`CoachOSConnectDeviceDiscoveryTests`): merge-/sorteerlogica, en controller-gedrag via de bestaande `MockBluetoothManager` uit Sprint 3 (scan-delegatie, discovery-publicatie, connect/foutafhandeling, stop-scan) — geen hardware nodig.

**Bewust niet toegevoegd**
- Herkenning van apparaattype (PM5 of anders) — blijft Sprint 5.
- Koppeling met `DeviceRepositoryProtocol`/`DeviceDescriptor` uit Core: een ontdekt BLE-apparaat is nog geen "gekoppeld apparaat" in de zin van de Device Layer — dat vraagt een adapter die weet hoe een generiek `BluetoothDevice` zich verhoudt tot een `DeviceDescriptor` met echte capabilities. Die koppeling hoort thuis bij Sprint 5, niet hier geforceerd.
- Multi-device tegelijk verbonden UX-afweging (bv. wat als je met twee apparaten tegelijk verbindt) — niet expliciet getest, wel technisch mogelijk door het per-`deviceId`-ontwerp van de controller.

**Let op — dekking door CI**
`App/` (inclusief `DevicesView.swift`, `RootView.swift`) is bewust geen
SwiftPM-target (zie eerdere sprints) en wordt dus niet door
`swift build`/`swift test` gedekt. Alle niet-triviale logica
(`DiscoveredDeviceList`, `DeviceDiscoveryController`) zit daarom in de wél
geteste module `CoachOSConnectDeviceDiscovery`; de SwiftUI-views zelf
blijven bewust dun en declaratief.

---

## CI-fix — race condition in DeviceDiscoveryController

CI-run op de Sprint 4-patch faalde met:

```
Tests/CoachOSConnectDeviceDiscoveryTests/DeviceDiscoveryControllerTests.swift:57:
XCTAssertEqual failed: ("[]") is not equal to ("[<device-id>]")
```

**Oorzaak:** `DeviceDiscoveryController.startScan()` riep
`bluetooth.discoveredDevicesStream()` aan *binnen* de achtergrond-`Task`
die de stream consumeert, in plaats van ervóór. Daardoor kon `startScan()`
al terugkeren voordat die Task daadwerkelijk gestart was. Een ontdekking
die in dat venster binnenkomt, wordt aan een nog niet bestaande
continuation "geyield" en gaat verloren — niet gebufferd, want er was nog
geen continuation om te bufferen. Op de mock (synchrone
`simulateDiscovery`) was dit venster breed genoeg om vrijwel altijd te
missen; met echte hardware is dit venster smaller maar principieel
hetzelfde risico.

**Gewijzigd**
- `Sources/CoachOSConnectDeviceDiscovery/DeviceDiscoveryController.swift`:
  - `startScan()`: `discoveredDevicesStream()` wordt nu synchroon aangeroepen
    vóórdat de consumerende `Task` wordt aangemaakt, en vóórdat
    `bluetooth.startScan(matching:)` het apparaat aan het werk zet.
  - `observeConnectionState(for:)`: zelfde volgorde-fix toegepast op
    `connectionStateStream(for:)`, al was dit niet de aanleiding — voor
    consistentie en om hetzelfde risico daar preventief te dichten.
- Geen enkele test gewijzigd; de bestaande
  `test_startScan_publishesDiscoveredDevices` hoort nu deterministisch te
  slagen zonder de timing van de `Task.sleep` te hoeven verruimen.

---

## Sprint 5a — PM5/CSAFE-encoding (pure, nog geen BLE)

Eerste stuk PM5-code in de repository. Bewust gescheiden van transport
(sectie 31/33 masterdocument): dit levert alleen de `PM5Protocol` en
`CSAFECommandEncoder`-lagen uit de architectuur in sectie 56 — nog geen
`CSAFETransport`, `BLETransport` of `PM5Adapter`. Die volgen in Sprint 5b,
zodra deze laag hier staat en getest is.

**Onderzoek vóór implementatie (per sectie 44-46, source confidence model)**

Twee stukken ontbrekende, niet eerder bevestigde informatie opgezocht en
bevestigd vóór er één regel code geschreven werd:

1. **PM5 BLE-servicedefinitie** (Level 1: officiële Concept2-documentatie,
   "Concept2 PM Bluetooth Smart Communication Interface Definition" Rev
   1.30) — GATT-service-/characteristic-UUID's voor Device Discovery,
   Device Information, C2 PM Control (CSAFE-commando's/-responses) en C2
   PM Rowing (live metrics, nog niet gebruikt).
2. **CSAFE-frame-structuur** (Level 1: officiële "Concept2 Performance
   Monitor CSAFE Communication Definition" Rev 0.27) — start-byte 0xF1,
   stop-byte 0xF2, byte-stuffing-vlag 0xF3 met volledige stuffing-tabel,
   checksum = XOR van de (ongestufte) inhoud. Geverifieerd door twee echte,
   in het wild vastgelegde CSAFE-frames uit Concept2-forumdiscussies
   handmatig na te rekenen — beide kloppen exact (zie testfixtures).
3. **Wrapper-mechaniek voor de acht bevestigde PM-commando's** (Level 2:
   ErgometerJS `command_core.ts`, onafhankelijk gekruist met
   tijmenvangulik's aparte PM3Monitor C++-project) — de acht eerder
   bevestigde commando's (0x01, 0x03, 0x04, 0x06, 0x14, 0x15, 0x17, 0x18)
   zijn geen top-level CSAFE-commando's, maar `detailCommand`-waarden onder
   het proprietary "long command" `SETPMCFG_CMD = 0x76`. Dit was niet
   expliciet vastgelegd in het eerdere onderzoek en zou zonder deze check
   tot een verkeerd frame-formaat hebben geleid.
4. **Bonus-vondst:** de officiële BLE-spec bevat de volledige
   `IntervalType`-enum (namen én waarden), inclusief de undefined-rest-
   varianten. Dit lost een deel van de eerder openstaande vraag op (sectie
   28-30 masterdocument) — de enum-waarden zijn nu bevestigd. Wat nog
   ontbreekt: een gevalideerd werkend voorbeeld van de volledige
   programmeersequentie voor die varianten. Daarom blijft `.openEnded`-duur
   (undefined rest) nog expliciet geweigerd in `PM5WorkoutProgrammer`, niet
   geïmplementeerd op basis van alleen de enum-waarde.

**Toegevoegd**
- Nieuwe module `CoachOSConnectPM5` (afhankelijk van alleen `CoachOSConnectCore`, geen Bluetooth-koppeling in deze sprint).
- `CSAFEByteStuffing`: stuff/unstuff volgens de bevestigde tabel.
- `CSAFEFrame`: encode/decode van complete frames (start/stop/checksum/stuffing), geverifieerd tegen twee echte gevangen frames.
- `PM5ProprietaryCommand`: de acht bevestigde commando's met hun exacte, bevestigde payload-encoding (eenheden, byte-volgorde, multipliers).
- `PM5Frame`: verpakt commando's onder de bevestigde `SETPMCFG_CMD`-wrapper tot verzendklare CSAFE-frames.
- `PM5BLEConstants`: GATT-UUID's, met bronvermelding, nog niet gekoppeld aan `CoachOSConnectBluetooth`.
- `PM5Error`: `unsupportedWorkoutConfiguration` — expliciete weigering in plaats van gokken, conform sectie 59.
- `PM5WorkoutProgrammer`: vertaalt `UniversalWorkout` naar geordende PM5-intervalblokken voor het bevestigde MVP-geval (tijdgebaseerde werk/hersteld-paren, `.power`/`.pace`-targets). Weigert expliciet: warm-up/cooldown, ongepaarde werkstappen, afstandgebaseerde duur, `.openEnded`-duur, niet-ondersteunde target-metrics.
- `Sources/CoachOSConnectCore/Models/UniversalWorkout.swift`: `WorkoutTarget`-documentatie uitgebreid met de eenheid-conventie per metric (`.power` = rauwe watts, `.pace` = seconden per 500m) — sluit het gat dat de Sprint 1-audit signaleerde.
- Tests (`CoachOSConnectPM5Tests`): elk bevestigd commando individueel, de `SETPMCFG_CMD`-wrapper, het bevestigde MVP-workoutgeval end-to-end, én elk expliciet geweigerd geval (zeven scenario's) — allemaal zonder BLE-hardware nodig.

**Bewust niet toegevoegd**
- BLE-verbinding/transport (`CSAFETransport`, `BLETransport`) — koppeling met `CoachOSConnectBluetooth` volgt in Sprint 5b.
- `PM5Adapter` conform `DeviceAdapterProtocol` — vraagt de transportlaag hierboven, dus ook Sprint 5b.
- Response-/statusframe-decodering (ontvangen data van de PM5 interpreteren) — alleen encoding (verzenden) zit in deze sprint.
- Live metrics — hoort bij de C2 Rowing Service, een latere sprint.
- Undefined-rest-workouts — enum-waarden nu bevestigd, werkende sequentie nog niet; blijft expliciet geweigerd.
- Afstandgebaseerde intervallen — de bevestigde MVP-keten is tijdgebaseerd.

---

## Sprint 5b — CSAFE Transport + BLE-koppeling + PM5Adapter

Verbindt de encoding-laag uit Sprint 5a met de generieke Bluetooth-laag uit
Sprint 3. Voor het eerst een `DeviceAdapterProtocol`-implementatie die
daadwerkelijk aanroepbaar is via de Device Layer.

**Aanvullend onderzoek vóór implementatie**

`startWorkout()`/`stopWorkout()` vragen om CSAFE-commando's die niet in het
Sprint 5a-onderzoek zaten (dat ging alleen over workout-programmeren, niet
over start/stop). Opgezocht en bevestigd via drie onafhankelijke bronnen
die elkaar exact bevestigen (officiële PM3-documentatie,
tijmenvangulik's PM3Monitor-C-header, het losse c2api-project) plus
daadwerkelijk PM5-over-BLE-verkeer uit een Concept2-forumdiscussie:
`CSAFE_GOINUSE_CMD = 0x85` (dichtstbijzijnde equivalent van "start") en
`CSAFE_GOFINISHED_CMD = 0x86` ("stop"). Voor pauzeren/hervatten is **geen**
bevestigd commando gevonden — blijft daarom expliciet geweigerd in plaats
van gegokt.

**Toegevoegd**
- `PM5ControlCommand`: de bevestigde standaard CSAFE-statuscommando's (`GETSTATUS`, `RESET`, `GOIDLE`, `GOHAVEID`, `GOINUSE`, `GOFINISHED`, `GOREADY`) — "short commands", geen wrapper, in tegenstelling tot de proprietary workoutcommando's uit Sprint 5a.
- `CSAFETransport`: koppelt CSAFE-framing aan `BluetoothManagerProtocol`. Verstuurt naar de Receive-characteristic (0x0021), ontvangt via notify-abonnement op de Transmit-characteristic (0x0022); verwerpt frames die niet aan de checksum voldoen stilzwijgend in plaats van ze als geldige data door te geven.
- `PM5Adapter`: volledige `DeviceAdapterProtocol`-implementatie. `connect()` scant (met timeout — zie hieronder), verbindt, ontdekt services, abonneert op responses; `sendWorkout()` gebruikt `PM5WorkoutProgrammer` + `CSAFETransport`; `startWorkout()`/`stopWorkout()` gebruiken de nieuw bevestigde commando's.
- `AppAssembly`: `PM5Adapter` daadwerkelijk geregistreerd bij de `DeviceLayer` — de placeholder die sinds Sprint 1 klaarstond is nu ingevuld.
- Tests (`CSAFETransportTests`, `PM5AdapterTests`): send/receive via `MockBluetoothManager`, een echt gevangen CSAFE-frame als fixture, connect/disconnect-statusovergangen, en elk expliciet geweigerd geval (pauzeren, hervatten) met een eigen test.

**Tijdens het bouwen zelf gevonden en gerepareerd (niet pas in CI)**
- `DeviceAdapterProtocol.state` is een synchrone `{ get }`-property; een
  `actor`-implementatie kan die niet zonder `await` aanbieden. `PM5Adapter`
  is daarom een `final class` met `NSLock`, hetzelfde patroon als
  `CoreBluetoothManager` — niet een architectuurwijziging, wel een
  toepassing van een bestaand patroon.
- Zonder timeout zou `connect()` voor altijd blijven hangen als er geen
  PM5 gevonden wordt (de discovery-stream sluit nooit vanzelf af).
  Opgelost met een race tussen discovery en een instelbare timeout
  (standaard 10s — een software-keuze, geen bevestigd PM5-specifiek getal).
- Dezelfde abonneer-vóór-actie-volgorde als de Sprint 4-racefix toegepast
  op `connect()`: `discoveredDevicesStream()` wordt nu vóór `startScan()`
  aangeroepen, niet erna.

**Bewust niet toegevoegd / bekende beperkingen (zie ook de doc-comments in `PM5Adapter.swift`)**
- `pauseWorkout()`/`resumeWorkout()` — expliciet geweigerd, geen bevestigd commando.
- `metricsStream()` — lege stream; C2 Rowing Service-decodering hoort bij Sprint 8.
- `batteryLevel()` — altijd `nil`; geen bevestigde characteristic gevonden.
- `sync()` — no-op; resultaatophaling (GET-commando's) hoort bij Sprint 7.
- `connect()` verbindt met het eerst gevonden PM5-achtige apparaat; kiezen tussen meerdere gelijktijdig zichtbare PM5's wordt nog niet ondersteund door deze adapter zelf.
- `startWorkout()`/`stopWorkout()` zijn geïmplementeerd volgens bevestigde commando's, maar niet gevalideerd tegen fysieke hardware — een forumdiscussie documenteert bekende onregelmatigheden in de PM5-CSAFE-statusmachine specifiek over Bluetooth op minstens één firmwareversie. Behandel als "geïmplementeerd, nog niet hardware-gevalideerd".

---

## Sprint 6b-1 — Native Supabase-authenticatie (CoachOS Connect-kant)

Eerste stuk van Sprint 6b (Connect-kant van het CoachOS-contract).
Uitsluitend authenticatie — workout-ophalen/-mapping en resultaat-
upload volgen in 6b-2/6b-3, bewust niet in dezelfde patch (zelfde
discipline als Sprint 5a/5b).

**Toegevoegd**
- `SupabaseAuthClientProtocol` + `SupabaseAuthClient`: authenticeert
  rechtstreeks tegen Supabase's eigen Auth-REST-API (GoTrue), zonder de
  officiële `supabase-swift`-SDK — consistent met "geen externe
  dependencies tenzij noodzakelijk". E-mail/wachtwoord bevestigd
  geïmplementeerd; Google-OAuth vanuit een native app bewust niet
  meegenomen (aparte, grotere redirect-flow, buiten deze sprint).
- `SecureTokenStoring` + `KeychainTokenStore`: sessieopslag via de iOS
  Keychain (Security-framework, geen dependency), nooit via
  `UserDefaults` of de gewone `FileLocalStorage`.
- `RemoteAuthRepository` volledig herschreven: gebruikt nu
  `SupabaseAuthClientProtocol`/`SecureTokenStoring` in plaats van het
  nep-`/api/v1/connect/auth/...`-endpoint dat de contract-review
  bevestigde als nooit bestaan te hebben.
- Nieuwe module-testtarget `CoachOSConnectDataTests`: eerste tests voor
  de Data-laag in dit project. `SupabaseAuthClient` getest via
  `MockURLProtocol` (geen echt netwerk); `RemoteAuthRepository` getest
  via fakes (geen netwerk, geen Keychain).
- `AppAssembly.assemble(...)`: nieuwe parameters `supabaseProjectURL`/
  `supabaseAnonKey`, los van `baseURL` (CoachOS-backend) — dit zijn
  bewust twee verschillende adressen (Supabase's eigen Auth-server vs.
  CoachOS' Next.js-backend).

**Gecorrigeerd**
- `CoachOSEndpoints.signIn()`/`refreshSession()` verwijderd — dode code,
  niemand roept ze meer aan, en ze wezen sowieso naar een endpoint dat
  nooit heeft bestaan.

**Bewust niet aangeraakt (nog steeds oude, onjuiste paden)**
- `CoachOSEndpoints.todaysWorkout()`/`workout(id:)`/`markCompleted()`/
  `syncItem()` — herzien hiervan vraagt ook de CoachOS-
  UniversalWorkout-mapping-laag (Sprint 6b-2). Half aanpassen zonder
  die laag zou compileren maar functioneel kapot zijn — bewust niet
  gedaan.

**Eerlijke, expliciete beperking**
- `KeychainTokenStore` is niet CI-getest — Keychain-toegang in de
  GitHub Actions macOS-runner-context zoals `swift test` die aanroept,
  is niet gegarandeerd hetzelfde als een echte, ontgrendelde iOS-
  Keychain. Volgt het standaard, gedocumenteerde Security-framework-
  patroon; behandel als "geïmplementeerd, nog niet hardware/CI-
  gevalideerd" — zelfde discipline als bij `PM5Adapter`.
- `supabaseAnonKey` in `App/CoachOSConnectApp.swift` staat als
  expliciete placeholder (`VUL_HIER_DE_ECHTE_PUBLISHABLE_KEY_IN`) — de
  echte waarde stond niet in de repository (`.env.example` bevat zelf
  ook alleen een placeholder), moet uit het Supabase-dashboard gehaald
  worden. De project-URL is wél echt (bevestigd publiek adres uit
  `.env.example`).

---

## Sprint 6b-2 — CoachOS-workout ophalen + mapping naar Connect's UniversalWorkout

Verbindt de auth-laag uit 6b-1 met de daadwerkelijke workout-keten:
`GET /api/today` → `sessieId` → `GET .../training-plan/workout` →
`CoachOSWorkoutMapper` → Connect's `UniversalWorkout`.

**Toegevoegd**
- `CoachOSTodayPlanDTO`/`CoachOSTodayResponseDTO`, `CoachOSWorkoutTargetDTO`/
  `CoachOSWorkoutBlockDTO`/`CoachOSUniversalWorkoutDTO`/
  `CoachOSWorkoutRouteResponseDTO`: exacte spiegels van CoachOS' eigen
  JSON, geverifieerd tegen `workout-builder/types.ts` en de daadwerkelijke
  route-responses (inclusief het rustdag-geval `{rest:true,reasons:[...]}`).
- `CoachOSWorkoutMapper`: vertaalt bloktype, herhaling (`repeat`+
  `rust_na_repeat_sec` → `RepeatGroup`), en targets (Optie B: alleen
  `power`/`pace` met een waarde worden gemapt; `zone` en overige typen
  bewust niet — landen als `instruction`-tekst, niet als hardware-target).
- `WorkoutStep.instruction: String?` (Core): nieuw, optioneel veld voor
  puur informatieve UI-tekst (bijv. een SPM-instructie) — nooit gebruikt
  voor CSAFE-encoding.
- `CoachOSEndpoints.today()`/`rowingWorkout(sessieId:)`: de echte,
  bevestigde paden, vervangen de nooit-bestaande `/api/v1/connect/...`.
- `RemoteWorkoutRepository` herschreven: implementeert de volledige
  today→sessieId→workout-keten; rustdag-respons wordt correct als "geen
  workout" (`nil`), niet als fout, behandeld.
- Tests (`CoachOSWorkoutMapperTests`): realistisch fixture-JSON (zie
  bronvermelding in het testbestand — handmatig opgebouwd naar het
  geverifieerde schema, geen live-capture), plus een end-to-end-test die
  bevestigt dat een gemapte workout ook daadwerkelijk voldoet aan
  `PM5WorkoutProgrammer`'s eisen.

**Twee reële gaten zelf gevonden tijdens het bouwen, gefixt of expliciet benoemd**
1. **Gefixt:** `PM5WorkoutProgrammer` verwachtte een strikte werk/rust-
   reeks vanaf stap 0 — elke echte CoachOS-workout heeft een losse
   `warmup[]`/`cooldown[]`, dus zonder fix zou geen enkele echte workout
   ooit geprogrammeerd hebben kunnen worden. Opgelost: leidende warmup en
   afsluitende cooldown worden nu overgeslagen (niet als CSAFE-interval
   verstuurd), blijven wel onderdeel van `UniversalWorkout.blocks` voor
   UI-weergave. Bestaande tests aangepast/uitgebreid.
2. **NIET gefixt, expliciet benoemd:** een los, niet-herhalend hoofdblok
   (bijv. een continue duurtraining zonder intervallen) heeft geen
   aansluitende rust-stap — `PM5WorkoutProgrammer` weigert dit nog steeds.
   Oplossen vraagt onderzoek naar welke PM5-commandosequentie een continue
   (niet-interval) workout nodig heeft (mogelijk een ander `WorkoutType`
   dan de bevestigde interval-varianten) — niet onderzocht in deze sprint,
   dus niet gegokt. Blijft een bekende beperking.

**Correctie op eerdere aanname**
- `recoveryBlocks` bleek in de huidige `bouwWorkout()`-implementatie
  ALTIJD leeg (`recoveryBlocks: []`, hardcoded in `builder.ts`) — mijn
  eerdere veronderstelling dat dit index-gebaseerd met `mainBlocks`
  correspondeert was ongefundeerd. De mapper ondersteunt de pairing toch
  (toekomstbestendig), maar met de documentatie gecorrigeerd naar wat de
  code daadwerkelijk doet.

**Bewust nog niet aangeraakt**
- `markCompleted()`/`syncItem()` (resultaat-upload) — Sprint 6b-3, wacht
  op een concreet upload-endpoint-ontwerp.
- `executionType`/CoachOS' `WorkoutType`-vertaling naar PM5's
  `SET_WORKOUTTYPE` — nog niet gekoppeld.
- Workout-niveau `targets[]` (naast per-blok-targets) — niet gemapt, geen
  Connect-gebruik voor op dit moment.

---

## Sprint 6b-3 — Resultaat-upload (Connect-kant)

Sluit de terugweg: `PM5 → Connect → lokale wachtrij → CoachOS →
activity_sessions`. Gebruikt uitsluitend het backend-contract dat al op
`coachOS` staat (`connect-result-bridge.ts`/`workout-result/route.ts`) —
geen eigen metrics-schema bedacht, zoals afgesproken.

**Belangrijke architectuurbeslissing (voorafgaand aan deze sprint,
vastgelegd in beide repo's):** `rowing-pm5-csafe-adapter.ts` en
`rowing-pm5-workout-request.ts` (CoachOS) zijn een tweede, onafhankelijk
gebouwde CSAFE-implementatie die daar werd aangetroffen. Besluit: Swift
Connect (`CoachOSConnectPM5`) blijft de enige runtime-implementatie; de
TypeScript-bestanden zijn gedeprecieerd (notitie toegevoegd, niet
verwijderd) en dienen alleen nog als validatiemateriaal — twee
onafhankelijke implementaties die tot nagenoeg identieke CSAFE-bytes
komen is sterk bewijs dat de Swift-kant klopt.

**Toegevoegd**
- `ConnectWorkoutResultPayload` (+ `Device`/`Totals`/`Interval`): exacte
  spiegel van het backend-request-body-schema, inclusief de bewust
  overgenomen gemengde camelCase/snake_case-naamgeving.
- `ConnectWorkoutResultBuilder`: pure, testbare functie die een
  verzendklaar `SyncItem` bouwt. Bewust nog niet gekoppeld aan een echte
  trainingssessie — er bestaat nergens in Connect nog een Workout Player
  (Sprint 9) die een training van start tot finish begeleidt.
- `CoachOSEndpoints.workoutResult(body:)`: het echte, bevestigde
  endpoint.
- `SyncItem` (Core): nieuw `payload: Data`-veld — `payloadReference`
  alleen was nooit genoeg om er daadwerkelijk iets mee te versturen.
- `LocalSyncRepository.sync(_:)` herschreven: routeert op `item.kind`
  naar het juiste, echte endpoint met de echte payload, niet langer het
  generieke `SyncItem`-object naar een placeholder-pad.
- Tests: payload-schema (camelCase/snake_case-mix, geverifieerd via ruwe
  JSON-inspectie, niet alleen round-trip), de builder, en
  `LocalSyncRepository` end-to-end via `MockURLProtocol` (bevestigt het
  daadwerkelijke aangeroepen pad).

**Gecorrigeerd**
- `CoachOSEndpoints.syncItem(body:)` verwijderd — was nooit meer dan een
  placeholder naar een nooit-bestaand pad.

**Bewust nog niet aangeraakt**
- Daadwerkelijke koppeling aan een echte trainingssessie (start/eind-
  tijdstip vastleggen, resultaat automatisch in de wachtrij zetten na
  `stopWorkout()`) — wacht op Sprint 9 (Workout Player). De plumbing
  staat klaar en is getest; er is alleen nog geen aanroeper.
- `totals`/`intervals` met echte waarden — wacht op Sprint 8 (live
  metrics-decodering). Vandaag zou een écht verstuurd resultaat alleen
  `sessieId`/`startedAt`/`completedAt`/`device` bevatten, exact zoals
  CoachOS' eigen Trainer AI-brug voor training/complete ("metrics blijft
  leeg i.p.v. iets te verzinnen").
- `liveMetricsSession`-sync (`SyncItemKind`) — geen bevestigd endpoint,
  gooit nu expliciet een fout i.p.v. te gokken.

---

## Optie B — UI voor SPM/coaching-instructies tijdens de training

Eerste van twee bekende gaten na Sprint 6b-3. Maakt de bestaande workout-
keten daadwerkelijk bruikbaar: de gebruiker ziet nu welke stap actief is,
hoeveel tijd resteert, en de door CoachOS aangeleverde
instructie/coachMessage (gevuld door `CoachOSWorkoutMapper` sinds Sprint
6b-2) — zonder dat de PM5 ooit een SPM-commando hoeft te kennen.

**Toegevoegd**
- Nieuwe module `CoachOSConnectWorkoutPlayback` (afhankelijk van alleen
  `CoachOSConnectCore`, geen hardware-/PM5-kennis).
- `WorkoutPlaybackController`: telt tijdgebaseerde stappen af op basis
  van de klok (injecteerbaar voor tests, geen echte `Task.sleep` in
  tests nodig). Afstand-/open-einde-stappen tellen niet automatisch af
  (geen betrouwbare manier zonder live PM5-telemetrie, Sprint 8) — de
  gebruiker gaat daar handmatig door via `advanceManually()`.
- `WorkoutStepKind.displayLabel`: Nederlandse fase-labels.
- `App/WorkoutPlaybackView.swift`: dunne SwiftUI-weergave — stap-teller,
  aftel-/verstreken-tijd, instructie-kaart, "Volgende stap"-knop waar
  relevant.
- `App/RootView.swift`: navigatielink naar het trainingsscherm zodra een
  workout is opgehaald.
- Tests (`CoachOSConnectWorkoutPlaybackTests`): countdown, automatisch
  doorschakelen bij tijdgebaseerde stappen, handmatig doorschakelen bij
  afstand-/open-einde-stappen, workout-afronding, lege workout, en de
  Nederlandse labels — allemaal met een injecteerbare klok, dus zonder
  ook maar één seconde te wachten.

**Bewust nog niet aangeraakt**
- Geen koppeling met `PM5Adapter.startWorkout()`/`stopWorkout()` — dit
  scherm toont alleen de voortgang, triggert nog niets op de hardware.
  Die koppeling hoort bij Sprint 9 (Workout Player) of een gerichte
  vervolgstap, niet stilzwijgend hier meegenomen.
- Pauzeren/hervatten binnen dit scherm — `PM5Adapter.pauseWorkout()`/
  `resumeWorkout()` zijn zelf al niet geïmplementeerd (geen bevestigd
  CSAFE-commando, zie Sprint 5b), dus dit scherm biedt bewust ook geen
  pauzeknop die iets zou suggereren wat niet klopt.
