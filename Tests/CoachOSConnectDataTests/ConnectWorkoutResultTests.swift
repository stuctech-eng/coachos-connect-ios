import XCTest
import CoachOSConnectCore
@testable import CoachOSConnectData

final class ConnectWorkoutResultTests: XCTestCase {

    private let startedAt = Date(timeIntervalSince1970: 1_756_000_000) // vaste datum, deterministisch
    private let completedAt = Date(timeIntervalSince1970: 1_756_001_500)

    func test_payload_encodesTopLevelFieldsAsCamelCase_andNestedFieldsAsSnakeCase() throws {
        // Exact het backend-contract: sessieId/startedAt/completedAt/device
        // camelCase, distance_m/avg_watts/etc. binnen totals/intervals
        // snake_case — bevestigd tegen de live workout-result/route.ts.
        let payload = ConnectWorkoutResultPayload(
            sessieId: "sessie-abc",
            startedAt: startedAt,
            completedAt: completedAt,
            device: .init(manufacturer: "Concept2", model: "PM5"),
            totals: .init(distanceM: 2000, avgWatts: 210, avgStrokeRate: 24, avgHeartRate: nil),
            intervals: [.init(index: 0, distanceM: 500, durationSec: 120, avgPaceSecPer500m: 105, avgWatts: 210, avgStrokeRate: 24)]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["sessieId"] as? String, "sessie-abc")
        XCTAssertNotNil(json["startedAt"])
        XCTAssertNotNil(json["completedAt"])

        let device = json["device"] as! [String: Any]
        XCTAssertEqual(device["manufacturer"] as? String, "Concept2")
        XCTAssertEqual(device["model"] as? String, "PM5")

        let totals = json["totals"] as! [String: Any]
        XCTAssertEqual(totals["distance_m"] as? Double, 2000)
        XCTAssertEqual(totals["avg_watts"] as? Double, 210)
        XCTAssertEqual(totals["avg_stroke_rate"] as? Double, 24)
        XCTAssertNil(totals["avg_heart_rate"])

        let intervals = json["intervals"] as! [[String: Any]]
        XCTAssertEqual(intervals.first?["distance_m"] as? Double, 500)
        XCTAssertEqual(intervals.first?["duration_sec"] as? Int, 120)
        XCTAssertEqual(intervals.first?["avg_pace_sec_per_500m"] as? Double, 105)
    }

    func test_payload_omitsAbsentTotalsAndIntervals() throws {
        // Vandaag realistisch: geen live metrics (Sprint 8), dus totals/
        // intervals typisch nil — bevestigt dat dit geldig encodeert.
        let payload = ConnectWorkoutResultPayload(
            sessieId: "sessie-abc",
            startedAt: startedAt,
            completedAt: completedAt,
            device: .init(manufacturer: "Concept2", model: "PM5")
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNil(json["totals"])
        XCTAssertNil(json["intervals"])
        XCTAssertEqual(json["sessieId"] as? String, "sessie-abc")
    }

    func test_builder_producesCompletedWorkoutSyncItemWithEncodedPayload() throws {
        let item = try ConnectWorkoutResultBuilder.makeSyncItem(
            sessieId: "sessie-xyz",
            startedAt: startedAt,
            completedAt: completedAt,
            deviceManufacturer: "Concept2",
            deviceModel: "PM5"
        )

        XCTAssertEqual(item.kind, .completedWorkout)
        XCTAssertEqual(item.payloadReference, "sessie-xyz")

        let decoded = try JSONSerialization.jsonObject(with: item.payload) as! [String: Any]
        XCTAssertEqual(decoded["sessieId"] as? String, "sessie-xyz")
    }

    // MARK: - LocalSyncRepository routeert op kind

    func test_localSyncRepository_completedWorkout_sendsPayloadToWorkoutResultEndpoint() async throws {
        let mockClient = MockURLProtocol.self
        var capturedRequest: URLRequest?
        mockClient.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        let apiClient = APIClient(baseURL: URL(string: "https://coachos.test")!, session: MockURLProtocol.makeSession())
        let storage = InMemoryLocalStorage()
        let repository = LocalSyncRepository(storage: storage, apiClient: apiClient)

        let item = try ConnectWorkoutResultBuilder.makeSyncItem(
            sessieId: "s1", startedAt: startedAt, completedAt: completedAt,
            deviceManufacturer: "Concept2", deviceModel: "PM5"
        )
        try await repository.enqueue(item)
        try await repository.sync(item)

        XCTAssertEqual(capturedRequest?.url?.path, "/api/specialists/rowing/training-plan/workout-result")
        let remaining = await repository.pendingSyncItems()
        XCTAssertTrue(remaining.isEmpty, "item moet uit de wachtrij verwijderd zijn na een geslaagde sync")
    }
}

// MARK: - Testdubbel

private final class InMemoryLocalStorage: LocalStorageProtocol, @unchecked Sendable {
    private var storage: [String: Data] = [:]

    func save<T: Encodable>(_ value: T, forKey key: String) async throws {
        storage[key] = try JSONEncoder().encode(value)
    }

    func load<T: Decodable>(_ type: T.Type, forKey key: String) async throws -> T? {
        guard let data = storage[key] else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func delete(forKey key: String) async throws {
        storage[key] = nil
    }
}
