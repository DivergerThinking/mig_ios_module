//
//  MIGHTTPClient.swift
//  MadridInGameiOSModule
//

import Foundation

/// Transport used by `MIGHTTPClient`. `URLSession` in production, scripted in tests.
protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPTransport {}

/// Single HTTP stack of the SDK: one `URLSession` with its own in-memory cookie storage
/// (isolated from the host app, never persisted) holding the member session, plus the gateway
/// contract, 401 renewal and 429 backoff. Every request of the SDK must go through here.
final class MIGHTTPClient: @unchecked Sendable {
    static let shared = MIGHTTPClient()

    let session: MIGSessionManager
    private let transport: HTTPTransport
    private let cookieStorage: HTTPCookieStorage?
    private let origin: @Sendable () -> String
    private let sleep: @Sendable (UInt64) async -> Void
    private let backoffSeconds: [UInt64]

    private convenience init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let urlSession = URLSession(configuration: configuration)
        let originProvider: @Sendable () -> String = { MIGEnvironment.current.origin }
        self.init(
            transport: urlSession,
            cookieStorage: configuration.httpCookieStorage,
            origin: originProvider,
            sessionEndpoint: HTTPSessionEndpoint(transport: urlSession, origin: originProvider)
        )
    }

    init(transport: HTTPTransport,
         cookieStorage: HTTPCookieStorage? = nil,
         origin: @escaping @Sendable () -> String,
         sessionEndpoint: SessionEndpoint,
         sleep: @escaping @Sendable (UInt64) async -> Void = { try? await Task.sleep(nanoseconds: $0 * 1_000_000_000) },
         backoffSeconds: [UInt64] = [1, 2, 4]) {
        self.transport = transport
        self.cookieStorage = cookieStorage
        self.origin = origin
        self.session = MIGSessionManager(endpoint: sessionEndpoint)
        self.sleep = sleep
        self.backoffSeconds = backoffSeconds
    }

    /// Sends a data request: on 401 renews the session once and replays once.
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let prepared = GatewayRequest.prepare(request, origin: origin())
        if await session.isStale() {
            _ = await session.renew(seenGeneration: await session.generation)
        }
        let generation = await session.generation
        let first = try await sendWithBackoff(prepared)
        guard first.1.statusCode == 401 else { return first }
        guard await session.renew(seenGeneration: generation) else { return first }
        return try await sendWithBackoff(prepared)
    }

    /// Forget the current member (new launch, environment change).
    func reset() async {
        cookieStorage?.cookies?.forEach { cookieStorage?.deleteCookie($0) }
        await session.clear()
    }

    private func sendWithBackoff(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var result = try await sendOnce(request)
        for delay in backoffSeconds where result.1.statusCode == 429 {
            await sleep(delay)
            result = try await sendOnce(request)
        }
        return result
    }

    private func sendOnce(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await transport.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        // Method + path + status only: queries, headers and bodies carry PII and credentials.
        Logger.shared.log("🛜 \(request.httpMethod ?? "GET") \(request.url?.path ?? "") \(http.statusCode)")
        return (data, http)
    }
}

/// `POST /api/member/session/` with `{"idToken": ...}`. The cookie lands in the session's storage.
struct HTTPSessionEndpoint: SessionEndpoint {
    let transport: HTTPTransport
    let origin: @Sendable () -> String

    func open(idToken: String) async -> Result<SessionProfile, MIGAuthError> {
        guard let url = URL(string: "\(origin())/api/member/session/"),
              let body = try? JSONSerialization.data(withJSONObject: ["idToken": idToken]) else {
            return .failure(.unexpected)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request = GatewayRequest.prepare(request, origin: origin())
        do {
            let (data, response) = try await transport.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failure(.unexpected) }
            Logger.shared.log("🛜 POST /api/member/session/ \(http.statusCode)")
            guard (200...299).contains(http.statusCode) else {
                let code = (try? JSONDecoder().decode(GatewayErrorEnvelope.self, from: data))?.code
                return .failure(.fromSessionStatus(http.statusCode, code: code))
            }
            guard let profile = (try? JSONDecoder().decode(SessionResponse.self, from: data))?.user else {
                return .failure(.unexpected)
            }
            return .success(profile)
        } catch {
            return .failure(.serviceUnavailable)
        }
    }
}
