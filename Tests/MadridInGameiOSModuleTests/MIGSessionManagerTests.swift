import XCTest
@testable import MadridInGameiOSModule

final class MIGSessionManagerTests: XCTestCase {
    private func provider(_ counter: Counter, token: String = "fresh") -> MIGIdTokenProvider {
        { forceRefresh in
            XCTAssertTrue(forceRefresh, "renewal must force a fresh token")
            await counter.increment()
            return token
        }
    }

    func testEstablishOpensTheSessionAndBumpsGeneration() async throws {
        let endpoint = ScriptedSessionEndpoint()
        let manager = MIGSessionManager(endpoint: endpoint)

        let profile = try await manager.establish(idToken: "initial")

        XCTAssertEqual(profile.id, "user-1")
        let tokens = await endpoint.tokens
        let generation = await manager.generation
        XCTAssertEqual(tokens, ["initial"])
        XCTAssertEqual(generation, 1)
    }

    func testEstablishRethrowsTheMappedError() async {
        let manager = MIGSessionManager(endpoint: ScriptedSessionEndpoint([.failure(.identityLinkRequired)]))
        do {
            try await manager.establish(idToken: "initial")
            XCTFail("expected identityLinkRequired")
        } catch {
            XCTAssertEqual(error as? MIGAuthError, .identityLinkRequired)
        }
    }

    func testBlankTokenFailsWithoutCallingTheServer() async {
        let endpoint = ScriptedSessionEndpoint()
        let manager = MIGSessionManager(endpoint: endpoint)
        do {
            try await manager.establish(idToken: " ")
            XCTFail("expected sessionExpired")
        } catch {
            XCTAssertEqual(error as? MIGAuthError, .sessionExpired)
        }
        let tokens = await endpoint.tokens
        XCTAssertTrue(tokens.isEmpty)
    }

    func testRenewAsksTheHostOnceAndReopensTheSession() async throws {
        let counter = Counter()
        let endpoint = ScriptedSessionEndpoint()
        let manager = MIGSessionManager(endpoint: endpoint)
        await manager.setProvider(provider(counter))
        try await manager.establish(idToken: "initial")
        let seen = await manager.generation

        let renewed = await manager.renew(seenGeneration: seen)

        XCTAssertTrue(renewed)
        let calls = await counter.value
        let tokens = await endpoint.tokens
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(tokens, ["initial", "fresh"])
    }

    func testOldGenerationReusesTheSessionRenewedByAnotherCaller() async throws {
        let counter = Counter()
        let manager = MIGSessionManager(endpoint: ScriptedSessionEndpoint())
        await manager.setProvider(provider(counter))
        try await manager.establish(idToken: "initial")
        let seen = await manager.generation

        _ = await manager.renew(seenGeneration: seen)
        let second = await manager.renew(seenGeneration: seen)

        XCTAssertTrue(second)
        let calls = await counter.value
        XCTAssertEqual(calls, 1)
    }

    func testConcurrent401sTriggerASingleRenewal() async throws {
        let counter = Counter()
        let manager = MIGSessionManager(endpoint: ScriptedSessionEndpoint())
        await manager.setProvider({ _ in
            await counter.increment()
            try await Task.sleep(nanoseconds: 50_000_000) // hold the renewal open while others arrive
            return "fresh"
        })
        try await manager.establish(idToken: "initial")
        let seen = await manager.generation

        let results = await withTaskGroup(of: Bool.self) { group -> [Bool] in
            for _ in 0..<8 { group.addTask { await manager.renew(seenGeneration: seen) } }
            return await group.reduce(into: []) { $0.append($1) }
        }

        XCTAssertEqual(results, Array(repeating: true, count: 8))
        let calls = await counter.value
        XCTAssertEqual(calls, 1)
    }

    func testProviderFailureEndsTheSessionAsExpired() async throws {
        let manager = MIGSessionManager(endpoint: ScriptedSessionEndpoint())
        let received = FailureBox()
        await manager.onFailure { error in Task { await received.set(error) } }
        await manager.setProvider({ _ in throw URLError(.userAuthenticationRequired) })
        try await manager.establish(idToken: "initial")

        let renewed = await manager.renew(seenGeneration: await manager.generation)

        XCTAssertFalse(renewed)
        try await Task.sleep(nanoseconds: 20_000_000)
        let failure = await received.value
        XCTAssertEqual(failure, .sessionExpired)
    }

    func testTransientServerErrorDoesNotEndTheSession() async throws {
        let manager = MIGSessionManager(endpoint: ScriptedSessionEndpoint([.success(SessionProfile(id: "u")), .failure(.serviceUnavailable)]))
        let received = FailureBox()
        await manager.onFailure { error in Task { await received.set(error) } }
        await manager.setProvider({ _ in "fresh" })
        try await manager.establish(idToken: "initial")

        let renewed = await manager.renew(seenGeneration: await manager.generation)

        XCTAssertFalse(renewed)
        try await Task.sleep(nanoseconds: 20_000_000)
        let failure = await received.value
        XCTAssertNil(failure)
    }

    func testSessionIsStaleAfter55Minutes() async throws {
        let clock = Clock()
        let manager = MIGSessionManager(endpoint: ScriptedSessionEndpoint(), clock: { clock.now })
        let noSession = await manager.isStale()
        XCTAssertFalse(noSession)

        try await manager.establish(idToken: "initial")
        clock.now = clock.now.addingTimeInterval(MIGSessionManager.staleAfter)
        let atLimit = await manager.isStale()
        XCTAssertFalse(atLimit)

        clock.now = clock.now.addingTimeInterval(1)
        let after = await manager.isStale()
        XCTAssertTrue(after)
    }
}

actor FailureBox {
    private(set) var value: MIGAuthError?
    func set(_ error: MIGAuthError) { value = error }
}

final class Clock: @unchecked Sendable {
    var now = Date(timeIntervalSince1970: 0)
}
