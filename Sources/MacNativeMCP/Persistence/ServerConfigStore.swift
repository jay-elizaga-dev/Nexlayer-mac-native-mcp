import Foundation

final class ServerConfigStore {
    private let key = "mcp.server_configs"

    func load() -> [AppState.ServerConfig] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let configs = try? JSONDecoder().decode([AppState.ServerConfig].self, from: data)
        else { return [] }
        return configs
    }

    func save(_ configs: [AppState.ServerConfig]) {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
