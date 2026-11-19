//
//  MIGIdTokenProvider.swift
//  MadridInGameiOSModule
//

import Foundation

/// Source of Azure AD B2C `id_token`s supplied by the host app.
///
/// The SDK calls it when its web session must be (re)established. Return the raw `id_token`
/// from MSAL (`MSALResult.idToken`). When `forceRefresh` is `true` the previous token was
/// rejected, so ask MSAL for a fresh one (`acquireTokenSilent` with `forceRefresh = true`).
/// Throw if the user must sign in again: the SDK shows its "session expired" screen and does
/// not retry in a loop.
public typealias MIGIdTokenProvider = @Sendable (_ forceRefresh: Bool) async throws -> String
