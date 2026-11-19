//
//  MIGAuthError.swift
//  MadridInGameiOSModule
//

import Foundation

/// Session errors shown to the user. Each one maps to a localized message.
enum MIGAuthError: Error, Equatable {
    /// The host could not provide a valid id_token, or the server rejected it.
    case sessionExpired
    /// The B2C identity must be linked to a profile by Madrid in Game support (409).
    case identityLinkRequired
    /// Authenticated, but the operation is not allowed for this account (403).
    case forbidden
    /// Network failure or server error (5xx/429).
    case serviceUnavailable
    /// Contract violation on our side (e.g. FORBIDDEN_ORIGIN, malformed response).
    case unexpected

    var isRetryable: Bool {
        self == .serviceUnavailable || self == .unexpected
    }

    var localizedMessage: String {
        switch self {
        case .sessionExpired: return "auth.session_expired".localized
        case .identityLinkRequired: return "auth.identity_link_required".localized
        case .forbidden: return "auth.forbidden".localized
        case .serviceUnavailable: return "auth.service_unavailable".localized
        case .unexpected: return "Error al cargar el módulo".localized
        }
    }

    /// Maps a failed `POST /api/member/session/` to a user-facing error.
    static func fromSessionStatus(_ status: Int, code: String?) -> MIGAuthError {
        switch status {
        case 401: return .sessionExpired
        case 409: return .identityLinkRequired
        case 403: return code == "FORBIDDEN_ORIGIN" ? .unexpected : .forbidden
        case 429, 500...599: return .serviceUnavailable
        default: return .unexpected
        }
    }

    static func from(_ error: Error) -> MIGAuthError {
        if let authError = error as? MIGAuthError { return authError }
        if error is URLError { return .serviceUnavailable }
        if case NetworkError.serverError(let status) = error {
            switch status {
            case 401: return .sessionExpired
            case 403: return .forbidden
            case 409: return .identityLinkRequired
            case 429, 500...599: return .serviceUnavailable
            default: return .unexpected
            }
        }
        return .unexpected
    }
}

extension MIGAuthError: LocalizedError {
    var errorDescription: String? { localizedMessage }
}
