import XCTest
@testable import MadridInGameiOSModule

final class GatewayRequestTests: XCTestCase {
    private let origin = "https://webesports.madridingame.es"

    func testGetGetsTrailingSlashKeepsQueryAndHasNoOrigin() {
        let request = URLRequest(url: URL(string: "\(origin)/api/data/items/competitions?fields=id")!)

        let prepared = GatewayRequest.prepare(request, origin: origin)

        XCTAssertEqual(rawPath(prepared.url), "/api/data/items/competitions/")
        XCTAssertEqual(prepared.url?.query, "fields=id")
        XCTAssertNil(prepared.value(forHTTPHeaderField: "Origin"))
    }

    func testMutationsCarryTheWebOrigin() {
        for method in ["POST", "PATCH", "DELETE"] {
            var request = URLRequest(url: URL(string: "\(origin)/api/data/items/gaming_space_reserves/12")!)
            request.httpMethod = method

            let prepared = GatewayRequest.prepare(request, origin: "\(origin)/")

            XCTAssertEqual(prepared.value(forHTTPHeaderField: "Origin"), origin, method)
            XCTAssertEqual(rawPath(prepared.url), "/api/data/items/gaming_space_reserves/12/")
        }
    }

    func testPathsOutsideTheApiAreUntouched() {
        let request = URLRequest(url: URL(string: "\(origin)/_next/static/media/rules.png")!)

        XCTAssertEqual(rawPath(GatewayRequest.prepare(request, origin: origin).url), "/_next/static/media/rules.png")
    }
}

final class MIGAuthErrorTests: XCTestCase {
    func testSessionStatusMapping() {
        XCTAssertEqual(MIGAuthError.fromSessionStatus(401, code: "INVALID_IDENTITY_TOKEN"), .sessionExpired)
        XCTAssertEqual(MIGAuthError.fromSessionStatus(409, code: "IDENTITY_LINK_REQUIRED"), .identityLinkRequired)
        XCTAssertEqual(MIGAuthError.fromSessionStatus(403, code: "FORBIDDEN_ORIGIN"), .unexpected)
        XCTAssertEqual(MIGAuthError.fromSessionStatus(403, code: "FORBIDDEN"), .forbidden)
        XCTAssertEqual(MIGAuthError.fromSessionStatus(429, code: nil), .serviceUnavailable)
        XCTAssertEqual(MIGAuthError.fromSessionStatus(503, code: nil), .serviceUnavailable)
        XCTAssertEqual(MIGAuthError.fromSessionStatus(400, code: "INVALID_BODY"), .unexpected)
    }

    func testErrorMapping() {
        XCTAssertEqual(MIGAuthError.from(URLError(.notConnectedToInternet)), .serviceUnavailable)
        XCTAssertEqual(MIGAuthError.from(NetworkError.serverError(statusCode: 401)), .sessionExpired)
        XCTAssertEqual(MIGAuthError.from(NetworkError.serverError(statusCode: 403)), .forbidden)
        XCTAssertEqual(MIGAuthError.from(NetworkError.serverError(statusCode: 409)), .identityLinkRequired)
        XCTAssertEqual(MIGAuthError.from(NetworkError.serverError(statusCode: 502)), .serviceUnavailable)
        XCTAssertEqual(MIGAuthError.from(NetworkError.decodingError), .unexpected)
    }

    func testOnlyTransientErrorsOfferRetry() {
        XCTAssertTrue(MIGAuthError.serviceUnavailable.isRetryable)
        XCTAssertFalse(MIGAuthError.sessionExpired.isRetryable)
        XCTAssertFalse(MIGAuthError.identityLinkRequired.isRetryable)
        XCTAssertFalse(MIGAuthError.forbidden.isRetryable)
    }

    func testEveryErrorHasALocalizedMessage() {
        for error in [MIGAuthError.sessionExpired, .identityLinkRequired, .forbidden, .serviceUnavailable] {
            XCTAssertFalse(error.localizedMessage.hasPrefix("auth."), "missing translation for \(error)")
        }
    }
}

final class SessionEndpointTests: XCTestCase {
    private let origin = "https://webesports.madridingame.es"

    func testSendsOnlyTheIdTokenAndParsesTheProfile() async throws {
        let body = Data(#"{"authenticated":true,"user":{"id":"u-1","status":"active","first_name":"Ana","avatar":"/api/data/assets/f-9"}}"#.utf8)
        let transport = ScriptedTransport(codes: [200], bodies: [body])
        let endpoint = HTTPSessionEndpoint(transport: transport, origin: { [origin] in origin })

        let result = await endpoint.open(idToken: "header.payload.signature")

        let profile = try result.get()
        XCTAssertEqual(profile.id, "u-1")
        XCTAssertEqual(profile.firstName, "Ana")
        XCTAssertEqual(profile.avatarId, "f-9")
        let sent = await transport.sent
        XCTAssertEqual(sent.first?.httpMethod, "POST")
        XCTAssertEqual(sent.first?.url?.absoluteString, "\(origin)/api/member/session/")
        XCTAssertEqual(sent.first?.value(forHTTPHeaderField: "Origin"), origin)
        let sentBody = try JSONSerialization.jsonObject(with: sent.first?.httpBody ?? Data()) as? [String: String]
        XCTAssertEqual(sentBody, ["idToken": "header.payload.signature"])
    }

    func testMapsTheGatewayErrorCode() async {
        let body = Data(#"{"errors":[{"message":"IDENTITY_LINK_REQUIRED","extensions":{"code":"IDENTITY_LINK_REQUIRED"}}]}"#.utf8)
        let endpoint = HTTPSessionEndpoint(transport: ScriptedTransport(codes: [409], bodies: [body]), origin: { [origin] in origin })

        let result = await endpoint.open(idToken: "token")

        XCTAssertEqual(result, .failure(.identityLinkRequired))
    }

    func testSuccessWithoutProfileIsUnexpected() async {
        let endpoint = HTTPSessionEndpoint(transport: ScriptedTransport(codes: [200], bodies: [Data(#"{"authenticated":false}"#.utf8)]),
                                           origin: { [origin] in origin })

        let result = await endpoint.open(idToken: "token")

        XCTAssertEqual(result, .failure(.unexpected))
    }

    func testAvatarIdFromGatewayPath() {
        XCTAssertEqual(SessionProfile(id: "u", avatar: "/api/data/assets/abc").avatarId, "abc")
        XCTAssertEqual(SessionProfile(id: "u", avatar: "/api/data/assets/abc/").avatarId, "abc")
        XCTAssertEqual(SessionProfile(id: "u", avatar: "abc").avatarId, "abc")
        XCTAssertNil(SessionProfile(id: "u", avatar: nil).avatarId)
    }

    func testUserModelIsBuiltFromTheSessionProfile() {
        let user = UserModel(profile: SessionProfile(id: "u", status: "active", email: "test@example.com", dni: "00000000T",
                                                     avatar: "/api/data/assets/abc"))
        XCTAssertEqual(user.id, "u")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.avatar, "abc")
        XCTAssertTrue(user.isDNIAvailable)
        XCTAssertTrue(user.isUserActive)
    }
}

final class EnvironmentTests: XCTestCase {
    func testUrlsGoThroughTheWebGateway() {
        let pro = EnvironmentManager.EnvironmentConfig.pro
        XCTAssertEqual(pro.origin, "https://webesports.madridingame.es")
        XCTAssertEqual(pro.getBaseURL(), "https://webesports.madridingame.es/api/data")
        XCTAssertEqual(pro.sessionURL, "https://webesports.madridingame.es/api/member/session/")
        XCTAssertEqual(EnvironmentManager.EnvironmentConfig.pre.getBaseURL(), "https://premig.randomkesports.com/api/data")
        XCTAssertFalse(pro.getBaseURL().contains("/cms"))
    }
}
