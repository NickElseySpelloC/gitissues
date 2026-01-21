//
//  GraphQLClient.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation

enum GraphQLError: LocalizedError {
    case noAccessToken
    case invalidURL
    case networkError(Error)
    case serverError(String)
    case decodingError(Error)
    case graphQLErrors([String])

    var errorDescription: String? {
        switch self {
        case .noAccessToken:
            return "No access token available. Please sign in."
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .graphQLErrors(let errors):
            return "GraphQL errors: \(errors.joined(separator: ", "))"
        }
    }
}

struct GraphQLRequest<T: Codable>: Codable {
    let query: String
    let variables: [String: AnyCodable]?

    init(query: String, variables: [String: Any]? = nil) {
        self.query = query
        self.variables = variables?.mapValues { AnyCodable($0) }
    }
}

struct GraphQLResponse<T: Codable>: Codable {
    let data: T?
    let errors: [GraphQLResponseError]?
}

struct GraphQLResponseError: Codable {
    let message: String
    let path: [String]?
    let locations: [Location]?

    struct Location: Codable {
        let line: Int
        let column: Int
    }
}

// Helper to encode Any values
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

class GraphQLClient {
    private let endpoint = "https://api.github.com/graphql"
    private let accessToken: String

    init(accessToken: String) {
        self.accessToken = accessToken
    }

    func execute<T: Codable>(
        query: String,
        variables: [String: Any]? = nil
    ) async throws -> T {
        guard let url = URL(string: endpoint) else {
            throw GraphQLError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let graphQLRequest = GraphQLRequest<T>(query: query, variables: variables)
        request.httpBody = try JSONEncoder().encode(graphQLRequest)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GraphQLError.serverError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw GraphQLError.serverError("HTTP \(httpResponse.statusCode)")
        }

        // Configure decoder for ISO8601 dates
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let graphQLResponse = try decoder.decode(GraphQLResponse<T>.self, from: data)

            if let errors = graphQLResponse.errors, !errors.isEmpty {
                let errorMessages = errors.map { $0.message }
                throw GraphQLError.graphQLErrors(errorMessages)
            }

            guard let data = graphQLResponse.data else {
                throw GraphQLError.serverError("No data in response")
            }

            return data
        } catch let error as DecodingError {
            throw GraphQLError.decodingError(error)
        }
    }
}
