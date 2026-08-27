import XCTest
@testable import CoachOSConnectData

final class SupabaseAuthClientTests: XCTestCase {

    private let projectURL = URL(string: "https://test-project.supabase.co")!

    func test_signIn_success_parsesTokenResponseIntoAuthSession() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString.contains("grant_type=password"), true)
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "test-anon-key")

            let json = """
            {
                "access_token": "access-123",
                "refresh_token": "refresh-456",
                "expires_in": 3600,
                "user": { "id": "user-789" }
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json.data(using: .utf8)!)
        }

        let client = SupabaseAuthClient(projectURL: projectURL, anonKey: "test-anon-key", session: MockURLProtocol.makeSession())
        let session = try await client.signIn(email: "roeier@voorbeeld.nl", password: "geheim")

        XCTAssertEqual(session.userId, "user-789")
        XCTAssertEqual(session.accessToken, "access-123")
        XCTAssertEqual(session.refreshToken, "refresh-456")
        XCTAssertTrue(session.expiresAt > Date())
    }

    func test_signIn_invalidCredentials_throwsSpecificError() async {
        MockURLProtocol.requestHandler = { request in
            let json = """
            { "error": "invalid_grant", "error_description": "Invalid login credentials" }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (response, json.data(using: .utf8)!)
        }

        let client = SupabaseAuthClient(projectURL: projectURL, anonKey: "test-anon-key", session: MockURLProtocol.makeSession())

        do {
            _ = try await client.signIn(email: "fout@voorbeeld.nl", password: "verkeerd")
            XCTFail("Verwachtte SupabaseAuthError.invalidCredentials")
        } catch SupabaseAuthError.invalidCredentials {
            // verwacht
        } catch {
            XCTFail("Onverwachte fout: \(error)")
        }
    }

    func test_signIn_serverError_throwsWithStatusCode() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let client = SupabaseAuthClient(projectURL: projectURL, anonKey: "test-anon-key", session: MockURLProtocol.makeSession())

        do {
            _ = try await client.signIn(email: "x@x.nl", password: "x")
            XCTFail("Verwachtte SupabaseAuthError.serverError")
        } catch SupabaseAuthError.serverError(let statusCode, _) {
            XCTAssertEqual(statusCode, 500)
        } catch {
            XCTFail("Onverwachte fout: \(error)")
        }
    }

    func test_refresh_usesRefreshTokenGrantType() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString.contains("grant_type=refresh_token"), true)
            let json = """
            {
                "access_token": "new-access",
                "refresh_token": "new-refresh",
                "expires_in": 3600,
                "user": { "id": "user-789" }
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json.data(using: .utf8)!)
        }

        let client = SupabaseAuthClient(projectURL: projectURL, anonKey: "test-anon-key", session: MockURLProtocol.makeSession())
        let session = try await client.refresh(refreshToken: "oud-refresh-token")

        XCTAssertEqual(session.accessToken, "new-access")
    }

    func test_signIn_malformedResponse_throwsDecodingFailed() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "{ \"onverwacht\": true }".data(using: .utf8)!)
        }

        let client = SupabaseAuthClient(projectURL: projectURL, anonKey: "test-anon-key", session: MockURLProtocol.makeSession())

        do {
            _ = try await client.signIn(email: "x@x.nl", password: "x")
            XCTFail("Verwachtte SupabaseAuthError.decodingFailed")
        } catch SupabaseAuthError.decodingFailed {
            // verwacht
        } catch {
            XCTFail("Onverwachte fout: \(error)")
        }
    }
}
