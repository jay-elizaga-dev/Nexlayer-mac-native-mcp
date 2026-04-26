import Foundation

// MARK: - Error

enum MCPClientError: Error, LocalizedError {
    case notConnected
    case serverError(code: Int, message: String)
    case missingResult

    var errorDescription: String? {
        switch self {
        case .notConnected: return "MCP client is not connected to a transport"
        case .serverError(let code, let message): return "Server error \(code): \(message)"
        case .missingResult: return "Response contained no result"
        }
    }
}

// MARK: - Pending requests (actor for thread safety)

private actor PendingRequests {
    private var nextId = 0
    private var continuations: [Int: CheckedContinuation<JSONRPCResponse, Error>] = [:]

    func nextRequestId() -> Int {
        nextId += 1
        return nextId
    }

    func add(id: Int, continuation: CheckedContinuation<JSONRPCResponse, Error>) {
        continuations[id] = continuation
    }

    func resume(id: Int, with response: JSONRPCResponse) {
        continuations.removeValue(forKey: id)?.resume(returning: response)
    }

    func resume(id: Int, throwing error: Error) {
        continuations.removeValue(forKey: id)?.resume(throwing: error)
    }

    func cancelAll(throwing error: Error) {
        for continuation in continuations.values {
            continuation.resume(throwing: error)
        }
        continuations.removeAll()
    }
}

// MARK: - MCPClient

@Observable
final class MCPClient {
    var state: ConnectionState = .disconnected
    var tools: [MCPTool] = []
    var serverInfo: MCPInitializeResult.ServerInfo?

    private var transport: (any MCPTransport)?
    private let pending = PendingRequests()

    enum ConnectionState: Equatable {
        case disconnected, connecting, ready, error(String)
    }

    func connect(transport: any MCPTransport) async throws {
        self.transport = transport
        state = .connecting
        startReceiveLoop()

        do {
            let initResult: MCPInitializeResult = try await sendRequest(
                method: "initialize",
                params: MCPInitializeParams(
                    clientInfo: .init(name: "MacNativeMCP", version: "1.0"),
                    capabilities: .init()
                )
            )
            serverInfo = initResult.serverInfo

            let notification = JSONRPCNotification(jsonrpc: "2.0", method: "notifications/initialized", params: nil)
            try await transport.send(JSONEncoder().encode(notification))

            let toolsResult: ListToolsResult = try await sendRequest(method: "tools/list")
            tools = toolsResult.tools

            state = .ready
        } catch {
            state = .error(error.localizedDescription)
            throw error
        }
    }

    func disconnect() {
        transport?.close()
        transport = nil
        state = .disconnected
    }

    func callTool(name: String, arguments: [String: Any]) async throws -> CallToolResult {
        let params = CallToolParams(name: name, arguments: AnyCodable(arguments))
        return try await sendRequest(method: "tools/call", params: params)
    }

    private func sendRequest<P: Encodable, R: Decodable>(method: String, params: P) async throws -> R {
        guard let transport else { throw MCPClientError.notConnected }
        let id = await pending.nextRequestId()
        let paramsData = try JSONEncoder().encode(params)
        let anyCodableParams = try JSONDecoder().decode(AnyCodable.self, from: paramsData)
        let request = JSONRPCRequest(id: id, method: method, params: anyCodableParams)
        return try await dispatchRequest(id: id, request: request, transport: transport)
    }

    private func sendRequest<R: Decodable>(method: String) async throws -> R {
        guard let transport else { throw MCPClientError.notConnected }
        let id = await pending.nextRequestId()
        let request = JSONRPCRequest(id: id, method: method, params: nil)
        return try await dispatchRequest(id: id, request: request, transport: transport)
    }

    private func dispatchRequest<R: Decodable>(
        id: Int,
        request: JSONRPCRequest,
        transport: any MCPTransport
    ) async throws -> R {
        let requestData = try JSONEncoder().encode(request)

        let response: JSONRPCResponse = try await withCheckedThrowingContinuation { continuation in
            Task {
                await pending.add(id: id, continuation: continuation)
                do {
                    try await transport.send(requestData)
                } catch {
                    await pending.resume(id: id, throwing: error)
                }
            }
        }

        if let rpcError = response.error {
            throw MCPClientError.serverError(code: rpcError.code, message: rpcError.message)
        }
        guard let result = response.result else {
            throw MCPClientError.missingResult
        }
        let resultData = try JSONEncoder().encode(result)
        return try JSONDecoder().decode(R.self, from: resultData)
    }

    private func startReceiveLoop() {
        guard let transport else { return }
        Task {
            while true {
                do {
                    let data = try await transport.receive()
                    guard
                        let response = try? JSONDecoder().decode(JSONRPCResponse.self, from: data),
                        let id = response.id
                    else { continue }
                    await pending.resume(id: id, with: response)
                } catch HTTPTransportError.timeout {
                    // No data arrived this cycle — keep looping; don't exit the loop.
                    continue
                } catch {
                    // Real transport error — cancel all pending requests and stop.
                    await pending.cancelAll(throwing: error)
                    return
                }
            }
        }
    }
}
