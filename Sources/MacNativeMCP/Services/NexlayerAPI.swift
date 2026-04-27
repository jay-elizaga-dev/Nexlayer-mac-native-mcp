import Foundation
import Observation

// MARK: - Errors

enum NexlayerAPIError: Error, LocalizedError {
    case httpError(Int)
    case decodingError(Error)
    case invalidResponse
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "HTTP error \(code)"
        case .decodingError(let error): return "Decoding error: \(error.localizedDescription)"
        case .invalidResponse: return "Invalid response"
        case .networkError(let error): return error.localizedDescription
        }
    }
}

// MARK: - Models

struct DeployStatus: Codable {
    let state: String
    let progress: Int?
}

struct DeployExtend: Codable {
    let available: Bool
    let expiresAt: String?
}

struct DeployClaim: Codable {
    let claimed: Bool
}

struct StartDeploymentResponse: Codable {
    let message: String
    let url: String?
    let sessionToken: String?
    let applicationName: String?
    let environment: String?
    let status: DeployStatus?
    let extend: DeployExtend?
    let claim: DeployClaim?
}

struct ReservedDeploymentStatus: Codable {
    let state: String
}

struct ReservedDeployment: Codable {
    let applicationName: String
    let environment: String?
    let url: String?
    let status: ReservedDeploymentStatus?
    let createdAt: String?
    let expiresAt: String?
}

struct GetReservationsResponse: Codable {
    let reservedDeployments: [ReservedDeployment]
}

struct ClaimDeploymentResponse: Codable {
    let message: String?
    let claimUrl: String?
    let claimToken: String?
}

struct ValidationError: Codable {
    let valid: Bool
    let errors: [String]?
}

struct ValidationSuccess: Codable {
    let message: String
}

struct NexlayerPod: Codable {
    let name: String
    let image: String
    let vars: [[String: String]]?
}

struct NexlayerApplication: Codable {
    let name: String
    let pods: [NexlayerPod]
}

struct ValidateRequest: Codable {
    let application: NexlayerApplication
}

// MARK: - API Client

@Observable
@MainActor
final class NexlayerAPI {
    var sessionToken: String?

    private let baseURL = URL(string: "https://api.nexlayer.com")!
    private let session = URLSession.shared

    // MARK: - Deployment

    func startDeployment(yaml: String, sessionToken: String? = nil) async throws -> StartDeploymentResponse {
        let url = baseURL.appendingPathComponent("startUserDeployment")
        let request = yamlRequest(url: url, yaml: yaml, sessionToken: sessionToken)
        let data = try await performRequest(request)
        do {
            return try JSONDecoder().decode(StartDeploymentResponse.self, from: data)
        } catch {
            throw NexlayerAPIError.decodingError(error)
        }
    }

    func updateDeployment(yaml: String, sessionToken: String) async throws -> StartDeploymentResponse {
        let url = baseURL.appendingPathComponent("updateUserDeployment")
        let request = yamlRequest(url: url, yaml: yaml, sessionToken: sessionToken)
        let data = try await performRequest(request)
        do {
            return try JSONDecoder().decode(StartDeploymentResponse.self, from: data)
        } catch {
            throw NexlayerAPIError.decodingError(error)
        }
    }

    func extendDeployment(applicationName: String, sessionToken: String) async throws -> String {
        let url = baseURL.appendingPathComponent("extendDeployment")
        let body = ["applicationName": applicationName, "sessionToken": sessionToken]
        let request = try jsonRequest(url: url, body: body)
        let data = try await performRequest(request)
        guard let result = String(data: data, encoding: .utf8) else {
            throw NexlayerAPIError.invalidResponse
        }
        return result
    }

    func claimDeployment(applicationName: String, sessionToken: String) async throws -> ClaimDeploymentResponse {
        let url = baseURL.appendingPathComponent("claimDeployment")
        let body = ["applicationName": applicationName, "sessionToken": sessionToken]
        let request = try jsonRequest(url: url, body: body)
        let data = try await performRequest(request)
        do {
            return try JSONDecoder().decode(ClaimDeploymentResponse.self, from: data)
        } catch {
            throw NexlayerAPIError.decodingError(error)
        }
    }

    // MARK: - Reservations

    func getReservations(sessionToken: String) async throws -> GetReservationsResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("getReservations"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "sessionToken", value: sessionToken)]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        let data = try await performRequest(request)
        do {
            return try JSONDecoder().decode(GetReservationsResponse.self, from: data)
        } catch {
            throw NexlayerAPIError.decodingError(error)
        }
    }

    func addReservation(applicationName: String, sessionToken: String) async throws {
        let url = baseURL.appendingPathComponent("addDeploymentReservation")
        let body = ["applicationName": applicationName, "sessionToken": sessionToken]
        let request = try jsonRequest(url: url, body: body)
        _ = try await performRequest(request)
    }

    func removeReservation(applicationName: String, sessionToken: String) async throws {
        let url = baseURL.appendingPathComponent("removeDeploymentReservation")
        let body = ["applicationName": applicationName, "sessionToken": sessionToken]
        let request = try jsonRequest(url: url, body: body)
        _ = try await performRequest(request)
    }

    func removeAllReservations(sessionToken: String) async throws {
        let url = baseURL.appendingPathComponent("removeReservations")
        let body = ["sessionToken": sessionToken]
        let request = try jsonRequest(url: url, body: body)
        _ = try await performRequest(request)
    }

    // MARK: - Validation

    func validate(application: NexlayerApplication) async throws -> ValidationSuccess {
        let url = baseURL.appendingPathComponent("validate")
        let request = try jsonRequest(url: url, body: ValidateRequest(application: application))

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NexlayerAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NexlayerAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let validationError = try? JSONDecoder().decode(ValidationError.self, from: data),
               let errors = validationError.errors, !errors.isEmpty {
                let nsError = NSError(
                    domain: "NexlayerValidation",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: errors.joined(separator: "; ")]
                )
                throw NexlayerAPIError.networkError(nsError)
            }
            throw NexlayerAPIError.httpError(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(ValidationSuccess.self, from: data)
        } catch {
            throw NexlayerAPIError.decodingError(error)
        }
    }

    // MARK: - Schema

    func getSchema() async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent("schema"))
        request.httpMethod = "GET"
        return try await performRequest(request)
    }

    // MARK: - Private Helpers

    private func performRequest(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NexlayerAPIError.networkError(error)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NexlayerAPIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NexlayerAPIError.httpError(httpResponse.statusCode)
        }
        return data
    }

    private func jsonRequest<T: Encodable>(url: URL, body: T) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func yamlRequest(url: URL, yaml: String, sessionToken: String?) -> URLRequest {
        var targetURL = url
        if let token = sessionToken {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "sessionToken", value: token)]
            targetURL = components.url!
        }
        var request = URLRequest(url: targetURL)
        request.httpMethod = "POST"
        request.setValue("text/x-yaml", forHTTPHeaderField: "Content-Type")
        request.httpBody = yaml.data(using: .utf8)
        return request
    }
}
