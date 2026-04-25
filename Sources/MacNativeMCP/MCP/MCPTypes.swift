import Foundation

// MARK: - AnyCodable

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable: unsupported type"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            let data = try JSONSerialization.data(withJSONObject: value)
            let json = try JSONSerialization.jsonObject(with: data)
            try container.encode(AnyCodable(json))
        }
    }
}

// MARK: - JSON-RPC base types

struct JSONRPCRequest: Codable {
    let jsonrpc: String
    var id: Int
    var method: String
    var params: AnyCodable?

    init(id: Int, method: String, params: AnyCodable? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

struct JSONRPCResponse: Codable {
    let jsonrpc: String
    var id: Int?
    var result: AnyCodable?
    var error: JSONRPCError?
}

struct JSONRPCError: Codable {
    var code: Int
    var message: String
}

struct JSONRPCNotification: Codable {
    let jsonrpc: String
    var method: String
    var params: AnyCodable?
}

// MARK: - MCP initialize

struct MCPInitializeParams: Codable {
    var protocolVersion: String
    var clientInfo: ClientInfo
    var capabilities: ClientCapabilities

    struct ClientInfo: Codable {
        var name: String
        var version: String
    }

    struct ClientCapabilities: Codable {
        // Extend with specific capability fields as the protocol evolves.
        // Currently empty to match the base spec.
    }

    init(clientInfo: ClientInfo, capabilities: ClientCapabilities = ClientCapabilities()) {
        self.protocolVersion = "2024-11-05"
        self.clientInfo = clientInfo
        self.capabilities = capabilities
    }
}

struct MCPInitializeResult: Codable {
    var protocolVersion: String
    var serverInfo: ServerInfo
    var capabilities: ServerCapabilities

    struct ServerInfo: Codable {
        var name: String
        var version: String
    }

    struct ServerCapabilities: Codable {
        var tools: ToolsCapability?
    }

    struct ToolsCapability: Codable {
        var listChanged: Bool?
    }
}

// MARK: - Tools

struct MCPTool: Codable, Identifiable {
    var name: String
    var description: String?
    var inputSchema: AnyCodable?

    var id: String { name }
}

struct ListToolsResult: Codable {
    var tools: [MCPTool]
}

struct CallToolParams: Codable {
    var name: String
    var arguments: AnyCodable?
}

struct CallToolResult: Codable {
    var content: [ContentItem]
    var isError: Bool?

    struct ContentItem: Codable {
        var type: String
        var text: String?
        var mimeType: String?
    }
}
