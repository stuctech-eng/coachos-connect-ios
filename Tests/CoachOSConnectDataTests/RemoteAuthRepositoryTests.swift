import XCTest
import CoachOSConnectCore
@testable import CoachOSConnectData

final class RemoteAuthRepositoryTests: XCTestCase {

    func test_signIn_savesSessionToTokenStore() async throws {
        let authClient = FakeSupabaseAuthClient()
        let tokenStore = InMemoryTokenStore()
        let repository = RemoteAuthRepository(authClient: authClient, tokenStore: tokenStore)

        let session = try await repository.signIn(email: "roeier@voorbeeld.nl", password: "geheim")

        XCTAssertEqual(session.userId, "fake-user")
        let saved = try await tokenStore.loadSession()
        XCTAssertEqual(saved?.accessToken, session.accessToken)
    }

    func test_currentSession_readsFromTokenStore() async throws {
        let tokenStore = InMemoryTokenStore()
        let existing = AuthSession(userId: "u1", accessToken: "a", refreshToken: "r", expiresAt: Date().addingTimeInterval(3600))
        try await tokenStore.save(existing)

        let repository = RemoteAuthRepository(authClient: FakeSupabaseAuthClient(), tokenStore: tokenStore)
        let session = await repository.currentSession()

        XCTAssertEqual(session?.userId, "u1")
    }

    func test_signOut_clearsTokenStore() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save(AuthSession(userId: "u1", accessToken: "a", refreshToken: "r", expiresAt: Date()))

        let repository = RemoteAuthRepository(authClient: FakeSupabaseAuthClient(), tokenStore: tokenStore)
        try await repository.signOut()

        let session = try await tokenStore.loadSession()
        XCTAssertNil(session)
    }

    func test_refreshSession_withoutExistingSession_throwsNotAuthenticated() async {
        let repository = RemoteAuthRepository(authClient: FakeSupabaseAuthClient(), tokenStore: InMemoryTokenStore())

        do {
            _ = try await repository.refreshSession()
            XCTFail("Verwachtte CoachOSConnectError.notAuthenticated")
        } catch CoachOSConnectError.notAuthenticated {
            // verwacht
        } catch {
            XCTFail("Onverwachte fout: \(error)")
        }
    }

    func test_refreshSession_usesCurrentRefreshTokenAndSavesNewSession() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save(AuthSession(userId: "u1", accessToken: "old", refreshToken: "refresh-token", expiresAt: Date()))
        let authClient = FakeSupabaseAuthClient()

        let repository = RemoteAuthRepository(authClient: authClient, tokenStore: tokenStore)
        let refreshed = try await repository.refreshSession()

        XCTAssertEqual(authClient.lastRefreshTokenUsed, "refresh-token")
        XCTAssertEqual(refreshed.accessToken, "fake-refreshed-access")
        let saved = try await tokenStore.loadSession()
        XCTAssertEqual(saved?.accessToken, "fake-refreshed-access")
    }
}

// MARK: - Testdubbels

private final class FakeSupabaseAuthClient: SupabaseAuthClientProtocol, @unchecked Sendable {
    private(set) var lastRefreshTokenUsed: String?

    func signIn(email: String, password: String) async throws -> AuthSession {
        AuthSession(userId: "fake-user", accessToken: "fake-access", refreshToken: "fake-refresh", expiresAt: Date().addingTimeInterval(3600))
    }

    func refresh(refreshToken: String) async throws -> AuthSession {
        lastRefreshTokenUsed = refreshToken
        return AuthSession(userId: "fake-user", accessToken: "fake-refreshed-access", refreshToken: "fake-refreshed-refresh", expiresAt: Date().addingTimeInterval(3600))
    }
}

private final class InMemoryTokenStore: SecureTokenStoring, @unchecked Sendable {
    private var stored: AuthSession?

    func save(_ session: AuthSession) async throws { stored = session }
    func loadSession() async throws -> AuthSession? { stored }
    func clear() async throws { stored = nil }
}
