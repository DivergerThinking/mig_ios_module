//
//  DirectusService.swift
//  Pods
//
//  Created by Arnau Rivas Rivas on 4/2/25.
//

import Foundation
import SwiftUI

enum NetworkError: Error {
    case invalidURL
    case invalidBody
    case noData
    case invalidResponse
    case serverError(statusCode: Int)
    case encodingError
    case decodingError
}

enum HTTPMethods: String {
    case GET
    case POST
    case PUT
    case PATCH
    case DELETE
    case HEAD
    case OPTIONS
}

extension NetworkError: LocalizedError {
    public var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidBody:
            return "Invalid Body"
        case .noData:
            return "No Data"
        case .invalidResponse:
            return "Invalid Response"
        case .serverError(let statusCode):
            return "Server Error (\(statusCode))"
        case .encodingError:
            return "Encoding Error"
        case .decodingError:
            return "Decoding Error"
        }
    }
    
    public var errorDescription: String? {
        localizedDescription
    }
}

actor DirectusService {
    // MARK: - Singleton Instance
    public static let shared = DirectusService()
    private init() {}

    // MARK: - Environment Manager
    private var environmentManager: EnvironmentManager?

    // MARK: - Setup Method
    public func configure(with environmentManager: EnvironmentManager) {
        self.environmentManager = environmentManager
    }

    // MARK: - Generic Fetch Function
    public func request<T: Decodable>(endpoint: String, method: HTTPMethods, parameters: [String: String]? = nil, body: [String: Any]? = nil) async throws -> T {
        let url = try itemsURL(endpoint: endpoint, parameters: parameters ?? [:])
        let data = try await send(url: url, method: method, body: body.map { sanitized($0, endpoint: endpoint, method: method) })
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            Logger.shared.log("Decoding error on \(method.rawValue) \(url.path)")
            throw NetworkError.decodingError
        }
    }

    // MARK: - Generic Send Function (POST, PATCH, PUT)
    public func sendRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethods,
        body: [String: Any]
    ) async throws -> T {
        return try await request(endpoint: endpoint, method: method, body: body)
    }

    public func request(
        endpoint: String,
        method: HTTPMethods,
        parameters: [String: Any] = [:],
        body: [String: Any] = [:]
    ) async throws -> Data? {
        let url = try itemsURL(endpoint: endpoint, parameters: parameters.mapValues { "\($0)" })
        return try await send(url: url, method: method, body: body.isEmpty ? nil : sanitized(body, endpoint: endpoint, method: method))
    }

    public func sendRequestWithoutDecode(
        endpoint: String,
        method: HTTPMethods,
        body: [String: Any]
    ) async throws {
        _ = try await request(endpoint: endpoint, method: method, body: body)
    }

    // MARK: - Trigger Flow (Webhook)
    public func triggerFlow(flowId: String, body: [String: Any]) async throws {
        guard let baseURL = environmentManager?.getBaseURL(),
              let url = URL(string: "\(baseURL)/flows/trigger/\(flowId)") else {
            throw NetworkError.invalidURL
        }
        _ = try await send(url: url, method: .POST, body: body)
    }

    // MARK: - Private

    private func sanitized(_ body: [String: Any], endpoint: String, method: HTTPMethods) -> [String: Any] {
        guard let collection = GatewayWritePolicy.collection(ofEndpoint: endpoint) else { return body }
        let result = GatewayWritePolicy.sanitize(collection: collection, method: method.rawValue, body: body)
        if !result.removed.isEmpty {
            Logger.shared.log("Dropped fields not accepted by the gateway on \(method.rawValue) \(collection): \(result.removed)")
        }
        return result.body
    }

    private func itemsURL(endpoint: String, parameters: [String: String]) throws -> URL {
        guard let baseURL = environmentManager?.getBaseURL(), !baseURL.isEmpty,
              var components = URLComponents(string: "\(baseURL)/items/\(endpoint)") else {
            throw NetworkError.invalidURL
        }
        if !parameters.isEmpty {
            components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw NetworkError.invalidURL }
        return url
    }

    /// Every call goes through the gateway client: session cookie, Origin, 401 renewal.
    private func send(url: URL, method: HTTPMethods, body: [String: Any]?) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await MIGHTTPClient.shared.send(request)
        guard (200...299).contains(response.statusCode) else {
            throw NetworkError.serverError(statusCode: response.statusCode)
        }
        return data
    }
}


extension String {
    var urlQueryValueEncoded: String? {
        return addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .replacingOccurrences(of: "+", with: "%2B")
    }
}
