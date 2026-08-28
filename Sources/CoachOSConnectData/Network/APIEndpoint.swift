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
/// Sprint 6b-2: `todaysWorkout()`/`workout(sessieId:)` gecorrigeerd naar
/// de echte, bevestigde CoachOS-paden (contract-review, 28 augustus
/// 2026). De oude `/api/v1/connect/...`-namespace is nooit een echt
/// contract geweest — zelf verzonnen in Sprint 1, vóór er een backend
/// was om tegen te toetsen.
///
/// `markCompleted`/`syncItem` (resultaat-upload naar `activity_sessions`)
/// staan hieronder BEWUST nog als placeholder — dat is Sprint 6b-3, wacht
/// op het CoachOS-backendwerk uit de contract-review (nieuwe
/// `coachos_connect`-source, al gedaan in Sprint 6a) plus een concreet
/// upload-endpoint-ontwerp dat nog niet vastligt.
public enum CoachOSEndpoints {

    /// `GET /api/today` — geeft `{ plan: TodayPlan }` terug. Bevat
    /// `source`/`sessieId`; alleen bij `source == "rowing"` en een
    /// niet-`nil` `sessieId` is er een PM5-workout voor vandaag.
    public static func today() -> APIEndpoint {
        APIEndpoint(path: "/api/today", method: .get)
    }

    /// `GET /api/specialists/rowing/training-plan/workout?sessieId=...`
    /// — geeft ofwel `{ workout, ... }` (reguliere trainingsdag) ofwel
    /// `{ rest: true, reasons: [...] }` (rustdag-beslissing) terug. Zie
    /// `CoachOSWorkoutRouteResponseDTO`.
    public static func rowingWorkout(sessieId: String) -> APIEndpoint {
        var components = URLComponents()
        components.path = "/api/specialists/rowing/training-plan/workout"
        components.queryItems = [URLQueryItem(name: "sessieId", value: sessieId)]
        return APIEndpoint(path: components.string ?? "/api/specialists/rowing/training-plan/workout", method: .get)
    }

    // MARK: - Sprint 6b-3 (nog niet geïmplementeerd)

    public static func markCompleted(id: String, body: Data) -> APIEndpoint {
        APIEndpoint(path: "/api/v1/connect/workouts/\(id)/complete", method: .post, body: body)
    }

    public static func syncItem(body: Data) -> APIEndpoint {
        APIEndpoint(path: "/api/v1/connect/sync", method: .post, body: body)
    }
}
