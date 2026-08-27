import Foundation
import CoachOSConnectCore

/// Generieke HTTP-client richting de CoachOS-backend. Kent geen
/// endpoint-specifieke logica — dat zit in de `APIEndpoint`-definities en
/// in de repository-implementaties die deze client gebruiken.
public actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private var accessTokenProvider: (@Sendable () async -> String?)?

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Wordt door de DI-laag gekoppeld aan `AuthRepositoryProtocol.currentSession()`
    /// zodat de client nooit zelf verantwoordelijk is voor sessiebeheer.
    public func setAccessTokenProvider(_ provider: @escaping @Sendable () async -> String?) {
        self.accessTokenProvider = provider
    }

    public func send<Response: Decodable>(_ endpoint: APIEndpoint) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint.path))
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body

        for (header, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: header)
        }

        if let token = await accessTokenProvider?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw CoachOSConnectError.sessionExpired
        default:
            throw APIClientError.serverError(statusCode: httpResponse.statusCode)
        }

        do {
            return try JSONDecoder.coachOSConnect.decode(Response.self, from: data)
        } catch {
            throw APIClientError.decodingFailed(underlying: error)
        }
    }

    /// Voor endpoints zonder verwachte response-body (bijv. markCompleted).
    public func sendWithoutResponse(_ endpoint: APIEndpoint) async throws {
        struct Empty: Decodable {}
        let _: Empty = try await send(endpoint)
    }
}

extension JSONDecoder {
    static let coachOSConnect: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
