import Foundation
import CoachOSConnectCore

/// Abstractie boven de daadwerkelijke Supabase Auth-aanroepen, zodat
/// `RemoteAuthRepository` getest kan worden zonder netwerk — zelfde
/// patroon als `BluetoothManagerProtocol`/`MockBluetoothManager`
/// elders in dit project.
public protocol SupabaseAuthClientProtocol: Sendable {
    func signIn(email: String, password: String) async throws -> AuthSession
    func refresh(refreshToken: String) async throws -> AuthSession
}
