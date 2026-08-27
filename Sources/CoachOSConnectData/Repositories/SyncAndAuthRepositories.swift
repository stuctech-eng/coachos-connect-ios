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

/// Authenticatie tegen hetzelfde CoachOS-account als de PWA — via
/// Supabase Auth rechtstreeks (`SupabaseAuthClientProtocol`), niet via
/// een CoachOS-backend-endpoint. Bevestigd tijdens de contract-review
/// (28 augustus 2026): CoachOS' eigen API-routes kennen geen
/// signin/refresh-pad, authenticatie loopt via Supabase zelf. Sessies
/// worden bewaard via `SecureTokenStoring` (Keychain in productie),
/// nooit via de gewone `LocalStorageProtocol`.
public final class RemoteAuthRepository: AuthRepositoryProtocol, @unchecked Sendable {
    private let authClient: SupabaseAuthClientProtocol
    private let tokenStore: SecureTokenStoring

    public init(authClient: SupabaseAuthClientProtocol, tokenStore: SecureTokenStoring) {
        self.authClient = authClient
        self.tokenStore = tokenStore
    }

    public func currentSession() async -> AuthSession? {
        try? await tokenStore.loadSession()
    }

    public func signIn(email: String, password: String) async throws -> AuthSession {
        let session = try await authClient.signIn(email: email, password: password)
        try await tokenStore.save(session)
        return session
    }

    public func signOut() async throws {
        try await tokenStore.clear()
    }

    public func refreshSession() async throws -> AuthSession {
        guard let current = await currentSession() else {
            throw CoachOSConnectError.notAuthenticated
        }
        let session = try await authClient.refresh(refreshToken: current.refreshToken)
        try await tokenStore.save(session)
        return session
    }
}
