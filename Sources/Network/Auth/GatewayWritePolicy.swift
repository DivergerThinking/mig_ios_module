//
//  GatewayWritePolicy.swift
//  MadridInGameiOSModule
//

import Foundation

/// Fields the web gateway accepts on each write (`madrid-ingame/client/lib/server/security/gateway-member*.ts`).
/// Any other field makes the gateway answer 403 FORBIDDEN, so they are dropped before sending.
/// Call sites already send the right bodies; this is the safety net that keeps the SDK and the gateway in sync.
enum GatewayWritePolicy {
    private static let reserveCreate: Set<String> = ["date", "user", "slot", "team", "training", "times", "companion_of"]
    private static let training: Set<String> = ["team", "notes", "time", "start_date", "type", "players", "reserves"]
    private static let inscription: Set<String> = ["id_user", "id_team", "id_tournament", "alias", "email"]
    private static let dni: Set<String> = ["user", "dni", "dni_front", "dni_back"]

    private static let rules: [String: Set<String>] = [
        "gaming_space_reserves POST": reserveCreate,
        "gaming_space_reserves PATCH": ["qrImage", "status"],
        "trainings POST": training,
        "trainings PATCH": training,
        "tournament_inscriptions POST": inscription,
        "tournament_inscriptions PATCH": inscription,
        "users PATCH": ["username", "avatar", "address", "dni"],
        "users_dni POST": dni,
        "users_dni PATCH": dni,
    ]

    /// `items/<collection>[/<id>]` → collection.
    static func collection(ofEndpoint endpoint: String) -> String? {
        let path = endpoint.split(separator: "?").first.map(String.init) ?? endpoint
        return path.split(separator: "/").first.map(String.init)
    }

    /// Returns the body the gateway accepts and the names of the dropped fields (never their values).
    static func sanitize(collection: String, method: String, body: [String: Any]) -> (body: [String: Any], removed: [String]) {
        guard let allowed = rules["\(collection) \(method.uppercased())"] else { return (body, []) }
        var result = body.filter { allowed.contains($0.key) }
        // A reservation can only be PATCHed to "cancelled"; any other status is rejected.
        if collection == "gaming_space_reserves", method.uppercased() == "PATCH",
           let status = result["status"] as? String, status != "cancelled" {
            result.removeValue(forKey: "status")
        }
        let removed = body.keys.filter { result[$0] == nil }.sorted()
        return (result, removed)
    }
}
