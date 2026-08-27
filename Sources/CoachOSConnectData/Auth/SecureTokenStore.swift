import Foundation
import Security
import CoachOSConnectCore

/// Abstractie boven veilige token-opslag, zodat repositories getest
/// kunnen worden zonder de iOS Keychain aan te raken.
public protocol SecureTokenStoring: Sendable {
    func save(_ session: AuthSession) async throws
    func loadSession() async throws -> AuthSession?
    func clear() async throws
}

/// Bewaart de `AuthSession` (access-/refresh-token) in de iOS Keychain —
/// nooit in `UserDefaults` of platte tekst, zoals vastgelegd in het
/// API-contract-voorstel. Gebruikt de Security-framework-API's
/// rechtstreeks (`SecItemAdd`/`SecItemCopyMatching`/`SecItemDelete`),
/// geen extra dependency.
///
/// BELANGRIJK, eerlijk: Keychain-toegang is in deze omgeving niet
/// CI-getest (geen macOS-Keychain beschikbaar op de manier die
/// `swift test` in GitHub Actions aanroept zonder een ontgrendelde
/// keychain/entitlements-context). De code volgt het standaard,
/// gedocumenteerde Security-framework-patroon; behandel als
/// "geïmplementeerd volgens de officiële API, nog niet in CI
/// geverifieerd" — dezelfde discipline als bij `PM5Adapter`s
/// hardware-afhankelijke delen.
public final class KeychainTokenStore: SecureTokenStoring, @unchecked Sendable {
    private let service: String
    private let account: String

    public init(service: String = "com.stuctech.coachosconnect", account: String = "auth-session") {
        self.service = service
        self.account = account
    }

    public func save(_ session: AuthSession) async throws {
        let data = try JSONEncoder().encode(session)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        // Bestaande waarde eerst verwijderen — SecItemAdd faalt op een
        // dubbele sleutel, SecItemUpdate is foutgevoeliger qua
        // attribuutmatching. Verwijderen+opnieuw toevoegen is het
        // aanbevolen, eenvoudigste patroon voor deze schaal.
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CoachOSConnectError.unknown(reason: "Keychain-opslag mislukt (status \(status)).")
        }
    }

    public func loadSession() async throws -> AuthSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound { return nil }
            throw CoachOSConnectError.unknown(reason: "Keychain-lezen mislukt (status \(status)).")
        }
        guard let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    public func clear() async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CoachOSConnectError.unknown(reason: "Keychain-verwijdering mislukt (status \(status)).")
        }
    }
}
