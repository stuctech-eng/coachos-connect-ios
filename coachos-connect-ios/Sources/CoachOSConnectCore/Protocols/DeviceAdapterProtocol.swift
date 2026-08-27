import Foundation

/// De universele interface die élke `DeviceAdapter` implementeert.
///
/// Dit protocol is de kern van de hele Device Layer-architectuur: CoachOS
/// Connect roept nooit fabrikant-specifieke code aan. Het kent alleen dit
/// protocol. Een nieuwe fabrikant toevoegen (Wahoo, Tacx, Garmin, Polar, ...)
/// betekent één nieuwe conforming type, zonder dat bestaande code wijzigt.
///
/// Sprint 1 levert alleen dit protocol en de eromheen liggende architectuur.
/// Er wordt in deze sprint geen enkele concrete adapter (PM5 of anders)
/// geïmplementeerd — zie `Sources/CoachOSConnectDeviceLayer/Adapters/README.md`.
public protocol DeviceAdapterProtocol: AnyObject, Sendable {

    /// Statische beschrijving van dit apparaattype: fabrikant, model, capabilities.
    var descriptor: DeviceDescriptor { get }

    /// Actuele status binnen de volledige levenscyclus (zie `DeviceState`).
    /// De UI-laag reageert hier direct op; use cases mogen ongeldige
    /// transities weigeren via `DeviceStateMachine.canTransition`.
    var state: DeviceState { get }

    /// Welke vaardigheden dit specifieke, verbonden apparaat op dit moment
    /// daadwerkelijk ondersteunt. Kan een subset zijn van `descriptor.capabilities`
    /// als bepaalde functies afhankelijk zijn van firmware of verbindingstype.
    func capabilities() -> Set<DeviceCapability>

    // MARK: Verbinding

    func connect() async throws
    func disconnect() async throws

    // MARK: Workout-uitvoering

    /// Stuurt een `UniversalWorkout` naar het apparaat. De adapter is
    /// verantwoordelijk voor de vertaling naar apparaat-specifieke commando's.
    func sendWorkout(_ workout: UniversalWorkout) async throws

    func startWorkout() async throws
    func pauseWorkout() async throws
    func resumeWorkout() async throws
    func stopWorkout() async throws

    // MARK: Live data

    /// Levert een stream van metriek-batches zolang het apparaat verbonden is.
    /// CoachOS Connect verwerkt deze stream niet inhoudelijk, het geeft hem door.
    func metricsStream() -> AsyncStream<LiveMetricsBatch>

    // MARK: Synchronisatie & status

    func sync() async throws
    func batteryLevel() async -> Int?
}
