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

/// Bekende endpoints richting de CoachOS-backend.
///
/// BELANGRIJKE CORRECTIE (contract-review, 28 augustus 2026): de
/// `/api/v1/connect/...`-namespace hieronder is NOOIT een echt CoachOS-
/// contract geweest — zelf verzonnen in Sprint 1, vóór er een backend was
/// om tegen te toetsen. De daadwerkelijke CoachOS-routes zijn anders
/// (`/api/today`, `/api/specialists/rowing/training-plan/workout?sessieId=...`,
/// géén auth-endpoints — authenticatie loopt via Supabase Auth
/// rechtstreeks, zie `SupabaseAuthClient`).
///
/// Sprint 6b-1 (deze patch) corrigeert alleen de auth-kant:
/// `signIn()`/`refreshSession()` zijn verwijderd (niemand roept ze meer
/// aan — `RemoteAuthRepository` gebruikt nu `SupabaseAuthClient`).
///
/// `todaysWorkout()`/`workout(id:)`/`markCompleted`/`syncItem` staan
/// hieronder BEWUST nog ongewijzigd (nog steeds de oude, onjuiste
/// `/api/v1/connect/...`-paden) — het herzien hiervan naar de echte
/// paden vraagt ook de CoachOS-UniversalWorkout-mapping-laag (Sprint
/// 6b-2), niet alleen een padwijziging. Half aanpassen zonder die laag
/// zou een compilerende maar functioneel kapotte staat opleveren; dat is
/// bewust niet gedaan.
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
}
