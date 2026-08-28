import Foundation

/// Levert workouts vanuit CoachOS (de bron van waarheid voor trainingslogica).
/// CoachOS Connect genereert nooit zelf een workout, het haalt ze op.
public protocol WorkoutRepositoryProtocol: Sendable {
    func fetchTodaysWorkout() async throws -> UniversalWorkout?
    func fetchWorkout(id: String) async throws -> UniversalWorkout
    func markWorkoutCompleted(id: UUID, completedAt: Date) async throws
}

/// Houdt bij welke apparaten bekend/gekoppeld zijn en geeft toegang tot
/// de juiste adapter via de `DeviceAdapterRegistry`. Bevat zelf geen
/// hardwarecommunicatie.
public protocol DeviceRepositoryProtocol: Sendable {
    func knownDevices() async -> [DeviceDescriptor]
    func pairDevice(_ descriptor: DeviceDescriptor) async throws
    func unpairDevice(id: String) async throws
}

/// Verantwoordelijk voor het synchroniseren van lokaal vastgelegde
/// trainingsdata naar CoachOS en eventuele externe diensten (Strava, HealthKit,
/// Garmin, ...). De daadwerkelijke koppelingen met externe diensten vallen
/// buiten Sprint 1.
public protocol SyncRepositoryProtocol: Sendable {
    func pendingSyncItems() async -> [SyncItem]
    func sync(_ item: SyncItem) async throws
    func syncAll() async throws
}

public struct SyncItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let kind: SyncItemKind
    public let payloadReference: String
    /// De daadwerkelijk te versturen data, al gecodeerd naar het exacte
    /// JSON-schema dat de bijbehorende CoachOS-endpoint verwacht (zie
    /// `ConnectWorkoutResultPayload` voor `.completedWorkout`).
    /// `payloadReference` alleen (een los ID-string) was nooit genoeg om
    /// er daadwerkelijk iets mee te versturen — deze aanvulling repareert
    /// dat gat, ontdekt tijdens Sprint 6b-3.
    public let payload: Data
    public let createdAt: Date

    public init(id: UUID = UUID(), kind: SyncItemKind, payloadReference: String, payload: Data, createdAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.payloadReference = payloadReference
        self.payload = payload
        self.createdAt = createdAt
    }
}

public enum SyncItemKind: String, Codable, Sendable {
    case completedWorkout
    case liveMetricsSession
}

/// Authenticatie tegen hetzelfde CoachOS-account als de PWA. CoachOS Connect
/// beheert geen eigen gebruikersmodel.
public protocol AuthRepositoryProtocol: Sendable {
    func currentSession() async -> AuthSession?
    func signIn(email: String, password: String) async throws -> AuthSession
    func signOut() async throws
    func refreshSession() async throws -> AuthSession
}

public struct AuthSession: Codable, Equatable, Sendable {
    public let userId: String
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date

    public init(userId: String, accessToken: String, refreshToken: String, expiresAt: Date) {
        self.userId = userId
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }
}
