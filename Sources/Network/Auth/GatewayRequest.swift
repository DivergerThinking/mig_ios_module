//
//  GatewayRequest.swift
//  MadridInGameiOSModule
//

import Foundation

/// Adapts every request to the web gateway contract:
/// - `/api/...` paths end with `/` (otherwise Next.js answers 308);
/// - mutations carry `Origin: <web origin>` (otherwise 403 FORBIDDEN_ORIGIN);
/// - no `Authorization` header ever leaves the SDK (auth is the session cookie).
enum GatewayRequest {
    private static let safeMethods: Set<String> = ["GET", "HEAD", "OPTIONS"]

    static func prepare(_ request: URLRequest, origin: String) -> URLRequest {
        var prepared = request
        prepared.setValue(nil, forHTTPHeaderField: "Authorization")
        if let url = request.url,
           var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           components.path.hasPrefix("/api/"), !components.path.hasSuffix("/") {
            components.path += "/"
            prepared.url = components.url ?? url
        }
        let method = (request.httpMethod ?? "GET").uppercased()
        if !safeMethods.contains(method) {
            var trimmed = origin
            while trimmed.hasSuffix("/") { trimmed.removeLast() }
            prepared.setValue(trimmed, forHTTPHeaderField: "Origin")
        }
        return prepared
    }
}
