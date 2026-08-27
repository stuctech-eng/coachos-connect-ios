import Foundation
import CoachOSConnectCore

/// Beheert de wachtrij van lokaal vastgelegde items die nog naar CoachOS (en
/// eventueel externe diensten) gesynchroniseerd moeten worden. De daadwerkelijke
/// koppeling met Strava/HealthKit/Garmin valt buiten Sprint 1 — hier staat
/// alleen de wachtrij-architectuur.
public final class LocalSyncRepository: SyncRepositoryProtocol, @unchecked Sendable {
    private let storage: LocalStorageProtocol
    private let apiClient: APIClient
    private let queueKey = "sync_queue"

    public init(storage: LocalStorageProtocol, apiClient: APIClient) {
        self.storage = storage
        self.apiClient = apiClient
    }

    public func pendingSyncItems() async -> [SyncItem] {
        (try? await storage.load([SyncItem].self, forKey: queueKey)) ?? []
    }

    public func sync(_ item: SyncItem) async throws {
        let payload = try JSONEncoder().encode(item)
        try await apiClient.sendWithoutResponse(CoachOSEndpoints.syncItem(body: payload))
        var remaining = await pendingSyncItems()
        remaining.removeAll { $0.id == item.id }
        try await storage.save(remaining, forKey: queueKey)
    }

    public func syncAll() async throws {
        let items = await pendingSyncItems()
        for item in items {
            try await sync(item)
        }
    }

    public func enqueue(_ item: SyncItem) async throws {
        var items = await pendingSyncItems()
        items.append(item)
        try await storage.save(items, forKey: queueKey)
    }
}

/// Authenticatie tegen hetzelfde CoachOS-account als de PWA. Sprint 1 levert
/// de structuur (sessieopslag, refresh-flow); de daadwerkelijke koppeling
/// aan het CoachOS-auth-endpoint wordt ingevuld zodra dat contract vaststaat.
public final class RemoteAuthRepository: AuthRepositoryProtocol, @unchecked Sendable {
    private let storage: LocalStorageProtocol
    private let apiClient: APIClient
    private let sessionKey = "auth_session"

    public init(storage: LocalStorageProtocol, apiClient: APIClient) {
        self.storage = storage
        self.apiClient = apiClient
    }

    public func currentSession() async -> AuthSession? {
        try? await storage.load(AuthSession.self, forKey: sessionKey)
    }

    public func signIn(email: String, password: String) async throws -> AuthSession {
        struct SignInBody: Encodable { let email: String; let password: String }
        let body = try JSONEncoder().encode(SignInBody(email: email, password: password))
        let endpoint = APIEndpoint(path: CoachOSEndpoints.signIn(), method: .post, body: body)
        let session: AuthSession = try await apiClient.send(endpoint)
        try await storage.save(session, forKey: sessionKey)
        return session
    }

    public func signOut() async throws {
        try await storage.delete(forKey: sessionKey)
    }

    public func refreshSession() async throws -> AuthSession {
        guard let current = await currentSession() else {
            throw CoachOSConnectError.notAuthenticated
        }
        struct RefreshBody: Encodable { let refreshToken: String }
        let body = try JSONEncoder().encode(RefreshBody(refreshToken: current.refreshToken))
        let endpoint = APIEndpoint(path: CoachOSEndpoints.refreshSession(), method: .post, body: body)
        let session: AuthSession = try await apiClient.send(endpoint)
        try await storage.save(session, forKey: sessionKey)
        return session
    }
}
