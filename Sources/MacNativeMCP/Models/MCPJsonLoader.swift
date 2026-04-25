import Foundation

enum MCPJsonLoader {
    // Paths to check, in priority order
    private static let searchPaths: [String] = [
        "\(NSHomeDirectory())/singlesourceoftruth/.mcp.json",
        "\(NSHomeDirectory())/.mcp.json",
        "\(NSHomeDirectory())/.claude/mcp.json",
    ]

    static func load() -> [AppState.ServerConfig] {
        for path in searchPaths {
            if let configs = parse(path: path) {
                return configs
            }
        }
        return []
    }

    private static func parse(path: String) -> [AppState.ServerConfig]? {
        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let mcpServers = json["mcpServers"] as? [String: Any]
        else { return nil }

        var configs: [AppState.ServerConfig] = []

        for (name, value) in mcpServers {
            guard let entry = value as? [String: Any] else { continue }

            var config = AppState.ServerConfig()
            config.name = name

            let type_ = entry["type"] as? String ?? "stdio"

            if type_ == "http", let url = entry["url"] as? String {
                config.transport = .http
                config.url = url
            } else {
                config.transport = .stdio
                config.command = entry["command"] as? String ?? ""
                config.args = entry["args"] as? [String] ?? []
                if let env = entry["env"] as? [String: String] {
                    config.envVars = env
                }
            }

            configs.append(config)
        }

        // Stable order: sort by name
        return configs.sorted { $0.name < $1.name }
    }
}
