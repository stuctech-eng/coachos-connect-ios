import Foundation
import CoachOSConnectCore

/// Rechtstreekse integratie met Supabase's eigen Auth-API (GoTrue),
/// zonder de officiële `supabase-swift`-SDK — consistent met de rest van
/// dit project ("geen externe afhankelijkheden tenzij noodzakelijk", zie
/// `Package.swift`). Supabase's Auth-REST-contract is stabiel en klein
/// genoeg om rechtstreeks aan te spreken.
///
/// CoachOS Connect authenticeert hiermee tegen HETZELFDE Supabase-project
/// als de CoachOS-PWA — zelfde account, geen tweede gebruikersmodel. Dit
/// is bevestigd tijdens de contract-review (28 augustus 2026): CoachOS
/// gebruikt Supabase Auth met e-mail/wachtwoord en Google-OAuth; deze
/// client implementeert het e-mail/wachtwoord-pad. Google-OAuth vanuit
/// een native app (met de bijbehorende redirect-flow) is bewust nog niet
/// meegenomen — apart, groter stuk werk, geen onderdeel van deze sprint.
public actor SupabaseAuthClient: SupabaseAuthClientProtocol {
    private let projectURL: URL
    private let anonKey: String
    private let session: URLSession

    /// - Parameters:
    ///   - projectURL: het Supabase-projectadres (bijv.
    ///     `https://xxxxx.supabase.co`), overeenkomend met CoachOS'
    ///     `NEXT_PUBLIC_SUPABASE_URL`.
    ///   - anonKey: de publieke/publishable Supabase-sleutel,
    ///     overeenkomend met CoachOS' `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`.
    ///     Dit is bewust een publieke sleutel (vergelijkbaar met hoe de
    ///     PWA 'm client-side gebruikt) — geen secret.
    public init(projectURL: URL, anonKey: String, session: URLSession = .shared) {
        self.projectURL = projectURL
        self.anonKey = anonKey
        self.session = session
    }

    public func signIn(email: String, password: String) async throws -> AuthSession {
        struct RequestBody: Encodable { let email: String; let password: String }
        let body = try JSONEncoder().encode(RequestBody(email: email, password: password))
        return try await tokenRequest(queryItem: URLQueryItem(name: "grant_type", value: "password"), body: body)
    }

    public func refresh(refreshToken: String) async throws -> AuthSession {
        struct RequestBody: Encodable { let refreshToken: String
            enum CodingKeys: String, CodingKey { case refreshToken = "refresh_token" }
        }
        let body = try JSONEncoder().encode(RequestBody(refreshToken: refreshToken))
        return try await tokenRequest(queryItem: URLQueryItem(name: "grant_type", value: "refresh_token"), body: body)
    }

    // MARK: - Interne helpers

    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: Int
        let user: TokenResponseUser

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case user
        }
    }

    private struct TokenResponseUser: Decodable {
        let id: String
    }

    private struct ErrorResponse: Decodable {
        let error: String?
        let errorDescription: String?
        let msg: String?

        enum CodingKeys: String, CodingKey {
            case error
            case errorDescription = "error_description"
            case msg
        }
    }

    private func tokenRequest(queryItem: URLQueryItem, body: Data) async throws -> AuthSession {
        var components = URLComponents(url: projectURL.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)
        components?.queryItems = [queryItem]
        guard let url = components?.url else {
            throw SupabaseAuthError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SupabaseAuthError.invalidResponse
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseAuthError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            let message = errorBody?.errorDescription ?? errorBody?.msg ?? errorBody?.error
            if httpResponse.statusCode == 400 {
                throw SupabaseAuthError.invalidCredentials
            }
            throw SupabaseAuthError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        let decoder = JSONDecoder()
        guard let tokenResponse = try? decoder.decode(TokenResponse.self, from: data) else {
            throw SupabaseAuthError.decodingFailed
        }

        return AuthSession(
            userId: tokenResponse.user.id,
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        )
    }
}
