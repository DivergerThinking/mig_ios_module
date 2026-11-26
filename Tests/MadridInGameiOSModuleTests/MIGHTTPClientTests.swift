import XCTest
@testable import MadridInGameiOSModule

final class MIGHTTPClientTests: XCTestCase {
    private let origin = "https://webesports.madridingame.es"

    private func makeClient(codes: [Int], provider: MIGIdTokenProvider? = { _ in "fresh" }) async throws
        -> (MIGHTTPClient, ScriptedTransport, Counter) {
        let transport = ScriptedTransport(codes: codes)
        let counter = Counter()
        let endpoint = ScriptedSessionEndpoint()
        let client = MIGHTTPClient(transport: transport, origin: { [origin] in origin }, sessionEndpoint: endpoint,
                                   sleep: { _ in }, backoffSeconds: [1, 2, 4])
        if let provider {
            await client.session.setProvider({ force in await counter.increment(); return try await provider(force) })
        }
        try await client.session.establish(idToken: "initial")
        return (client, transport, counter)
    }

    private func request(_ path: String, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: URL(string: "\(origin)\(path)")!)
        request.httpMethod = method
        return request
    }

    func test401RenewsOnceAndReplaysOnce() async throws {
        let (client, transport, counter) = try await makeClient(codes: [401, 200])

        let (_, response) = try await client.send(request("/api/data/items/trainings"))

        XCTAssertEqual(response.statusCode, 200)
        let sent = await transport.sent
        let renewals = await counter.value
        XCTAssertEqual(sent.count, 2)
        XCTAssertEqual(renewals, 1)
    }

    func testSecond401IsReturnedWithoutLooping() async throws {
        let (client, transport, counter) = try await makeClient(codes: [401, 401, 401])

        let (_, response) = try await client.send(request("/api/data/items/trainings"))

        XCTAssertEqual(response.statusCode, 401)
        let sent = await transport.sent
        let renewals = await counter.value
        XCTAssertEqual(sent.count, 2)
        XCTAssertEqual(renewals, 1)
    }

    func test403WithLostSessionRenewsAndReplays() async throws {
        // data 403 → session probe 401 → renewal → replay 200
        let (client, transport, counter) = try await makeClient(codes: [403, 401, 200])

        let (_, response) = try await client.send(request("/api/data/items/trainings"))

        XCTAssertEqual(response.statusCode, 200)
        let sent = await transport.sent
        XCTAssertEqual(sent.map { rawPath($0.url) }, ["/api/data/items/trainings/", "/api/member/session/", "/api/data/items/trainings/"])
        let renewals = await counter.value
        XCTAssertEqual(renewals, 1)
    }

    func test403WithValidSessionIsARealForbidden() async throws {
        // data 403 → session probe 200 → no renewal
        let (client, transport, counter) = try await makeClient(codes: [403, 200])

        let (_, response) = try await client.send(request("/api/data/items/trainings"))

        XCTAssertEqual(response.statusCode, 403)
        let sent = await transport.sent
        let renewals = await counter.value
        XCTAssertEqual(sent.count, 2)
        XCTAssertEqual(renewals, 0)
    }

    func testOtherStatusesPassThrough() async throws {
        let (client, transport, counter) = try await makeClient(codes: [409])

        let (_, response) = try await client.send(request("/api/data/items/trainings"))

        XCTAssertEqual(response.statusCode, 409)
        let sent = await transport.sent
        let renewals = await counter.value
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(renewals, 0)
    }

    func test429BacksOffThenGivesUp() async throws {
        let (client, transport, _) = try await makeClient(codes: [429, 429, 429, 429, 200])

        let (_, response) = try await client.send(request("/api/data/items/teams"))

        XCTAssertEqual(response.statusCode, 429)
        let sent = await transport.sent
        XCTAssertEqual(sent.count, 4)
    }

    func testRequestsFollowTheGatewayContract() async throws {
        let (client, transport, _) = try await makeClient(codes: [200])
        var post = request("/api/data/items/gaming_space_reserves", method: "POST")
        post.setValue("Bearer legacy", forHTTPHeaderField: "Authorization")

        _ = try await client.send(post)

        let sent = await transport.sent
        XCTAssertEqual(rawPath(sent.first?.url), "/api/data/items/gaming_space_reserves/")
        XCTAssertEqual(sent.first?.value(forHTTPHeaderField: "Origin"), origin)
        XCTAssertNil(sent.first?.value(forHTTPHeaderField: "Authorization"))
    }
}
