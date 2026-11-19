//
//  MIGSessionManager.swift
//  MadridInGameiOSModule
//

import Foundation

/// Exchanges an id_token for the web session cookie. Implemented over HTTP in production.
protocol SessionEndpoint: Sendable {
    func open(idToken: String) async -> Result<SessionProfile, MIGAuthError>
}

/// Owns the member web session (`ingame-member-session` cookie, 1 h TTL).
///
/// Renewal is single-flight: every request records `generation` before being sent; when several
/// of them get a 401 at once, only the first one asks the host for a new id_token and the rest
/// await the same renewal.
actor MIGSessionManager {
    static let staleAfter: TimeInterval = 55 * 60

    private let endpoint: SessionEndpoint
    private let clock: @Sendable () -> Date

    private(set) var provider: MIGIdTokenProvider?
    private(set) var generation = 0
    private var hasSession = false
    private var establishedAt = Date.distantPast
    private var renewal: Task<Bool, Never>?
    private var failureHandler: (@Sendable (MIGAuthError) -> Void)?

    init(endpoint: SessionEndpoint, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.endpoint = endpoint
        self.clock = clock
    }

    func setProvider(_ provider: MIGIdTokenProvider?) {
        self.provider = provider
    }

    /// Called when the session is lost for good (host could not provide a valid token).
    func onFailure(_ handler: (@Sendable (MIGAuthError) -> Void)?) {
        failureHandler = handler
    }

    /// Opens a session with `idToken`.
    @discardableResult
    func establish(idToken: String) async throws -> SessionProfile {
        guard !idToken.trimmingCharacters(in: .whitespaces).isEmpty else { throw MIGAuthError.sessionExpired }
        switch await endpoint.open(idToken: idToken) {
        case .success(let profile):
            generation += 1
            hasSession = true
            establishedAt = clock()
            return profile
        case .failure(let error):
            throw error
        }
    }

    /// Asks the host for a fresh id_token and reopens the session, unless another caller already
    /// did it after `seenGeneration`. Returns `true` when a valid session is available.
    func renew(seenGeneration: Int) async -> Bool {
        if generation != seenGeneration && hasSession { return true }
        if let renewal { return await renewal.value }
        let task = Task { await self.performRenewal() }
        renewal = task
        let result = await task.value
        renewal = nil
        return result
    }

    /// The server session lasts 1 h; renew a bit earlier to avoid a failed request.
    func isStale() -> Bool {
        hasSession && clock().timeIntervalSince(establishedAt) > Self.staleAfter
    }

    func clear() {
        hasSession = false
        establishedAt = .distantPast
        generation += 1
        renewal = nil
    }

    private func performRenewal() async -> Bool {
        guard let provider else { return fail(.sessionExpired) }
        let token: String
        do {
            token = try await provider(true)
        } catch {
            return fail(.sessionExpired)
        }
        do {
            try await establish(idToken: token)
            return true
        } catch {
            let authError = MIGAuthError.from(error)
            // Only a definitive rejection ends the session; network errors may recover on retry.
            return authError.isRetryable ? false : fail(authError)
        }
    }

    private func fail(_ error: MIGAuthError) -> Bool {
        failureHandler?(error)
        return false
    }
}
