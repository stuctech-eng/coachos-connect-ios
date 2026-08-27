import Foundation

public struct APIEndpoint: Sendable {
    public enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }

    public let path: String
    public let method: Method
    public let headers: [String: String]
    public let body: Data?

    public init(path: String, method: Method, headers: [String: String] = ["Content-Type": "application/json"], body: Data? = nil) {
        self.path = path
        self.method = method
        self.headers = headers
        self.body = body
    }
}

public enum APIClientError: Error, Sendable {
    case invalidResponse
    case serverError(statusCode: Int)
    case decodingFailed(underlying: Error)
}

/// Bekende endpoints richting de CoachOS-backend. Wordt uitgebreid naarmate
/// repository-implementaties in latere sprints echte calls gaan doen; in
/// Sprint 1 dient dit als vaste structuur, nog niet gekoppeld aan een live
/// backend-contract.
///
/// Alle paden zijn geversioneerd (`/api/v1/...`). Een toekomstige v2 van het
/// CoachOS-contract kan zo naast v1 blijven bestaan zolang oudere
/// Connect-versies nog in gebruik zijn, in plaats van dat elke
/// backend-wijziging direct alle geïnstalleerde apps breekt.
public enum CoachOSEndpoints {
    private static let basePath = "/api/v1/connect"

    public static func todaysWorkout() -> APIEndpoint {
        APIEndpoint(path: "\(basePath)/workouts/today", method: .get)
    }

    public static func workout(id: String) -> APIEndpoint {
        APIEndpoint(path: "\(basePath)/workouts/\(id)", method: .get)
    }

    public static func markCompleted(id: String, body: Data) -> APIEndpoint {
        APIEndpoint(path: "\(basePath)/workouts/\(id)/complete", method: .post, body: body)
    }

    public static func syncItem(body: Data) -> APIEndpoint {
        APIEndpoint(path: "\(basePath)/sync", method: .post, body: body)
    }

    public static func signIn() -> String { "\(basePath)/auth/signin" }
    public static func refreshSession() -> String { "\(basePath)/auth/refresh" }
}
