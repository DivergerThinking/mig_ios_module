import Foundation
@testable import MadridInGameiOSModule

/// Transport answering scripted status codes and recording every request.
actor ScriptedTransport: HTTPTransport {
    private var codes: [Int]
    private var bodies: [Data]
    private(set) var sent: [URLRequest] = []

    init(codes: [Int], bodies: [Data] = []) {
        self.codes = codes
        self.bodies = bodies
    }

    nonisolated func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await record(request)
    }

    private func record(_ request: URLRequest) throws -> (Data, URLResponse) {
        sent.append(request)
        let code = codes.isEmpty ? 200 : codes.removeFirst()
        let body = bodies.isEmpty ? Data("{}".utf8) : bodies.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}

/// Session endpoint answering scripted results.
actor ScriptedSessionEndpoint: SessionEndpoint {
    private var results: [Result<SessionProfile, MIGAuthError>]
    private(set) var tokens: [String] = []

    init(_ results: [Result<SessionProfile, MIGAuthError>] = []) {
        self.results = results
    }

    nonisolated func open(idToken: String) async -> Result<SessionProfile, MIGAuthError> {
        await next(idToken)
    }

    private func next(_ token: String) -> Result<SessionProfile, MIGAuthError> {
        tokens.append(token)
        return results.isEmpty ? .success(SessionProfile(id: "user-1")) : results.removeFirst()
    }
}

/// Thread-safe call counter for providers.
actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}

/// `URL.path` drops the trailing slash; the gateway contract is about the raw path.
func rawPath(_ url: URL?) -> String? {
    url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.path }
}
