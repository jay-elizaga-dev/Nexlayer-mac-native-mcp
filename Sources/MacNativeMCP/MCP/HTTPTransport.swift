import Foundation

final class HTTPTransport: MCPTransport {
    private let url: URL
    private(set) var sessionId: String?
    private var pendingResponses: [Data] = []

    private let bearerToken: String?

    init(url: URL, sessionId: String? = nil, bearerToken: String? = nil) {
        self.url = url
        self.sessionId = sessionId
        self.bearerToken = bearerToken
    }

    func send(_ data: Data) async throws {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        if let token = bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let sid = sessionId {
            request.setValue(sid, forHTTPHeaderField: "Mcp-Session-Id")
        }
        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse,
           let sid = http.value(forHTTPHeaderField: "Mcp-Session-Id") {
            sessionId = sid
        }

        let contentType = (response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Type") ?? ""

        if contentType.contains("text/event-stream") {
            pendingResponses.append(contentsOf: parseSSE(responseData))
        } else {
            pendingResponses.append(responseData)
        }
    }

    func receive() async throws -> Data {
        // Simple poll — fine for request/response HTTP MCP
        for _ in 0..<300 {  // 3s timeout
            if !pendingResponses.isEmpty { return pendingResponses.removeFirst() }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        throw HTTPTransportError.timeout
    }

    func close() { sessionId = nil }

    private func parseSSE(_ data: Data) -> [Data] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return text
            .components(separatedBy: "\n")
            .filter { $0.hasPrefix("data: ") }
            .compactMap { $0.dropFirst(6).data(using: .utf8) }
    }
}

enum HTTPTransportError: Error, LocalizedError {
    case timeout
    var errorDescription: String? { "HTTP transport timed out waiting for response" }
}
