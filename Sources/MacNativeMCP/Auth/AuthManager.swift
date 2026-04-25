import Foundation
import AppKit
import Observation
import Security

@Observable
@MainActor
final class AuthManager {
    enum State: Equatable {
        case checking
        case unauthenticated
        case connecting
        case authenticated
        case error(String)
    }

    var state: State = .checking
    var currentAPIKey: String?
    var devEnvKey: String?

    private let nexlayerURL = URL(string: "https://mcp.nexlayer.ai/api/mcp")!
    private let keychainService = "dev.elizaga.mac-native-mcp"
    private let keychainAccount = "nexlayer-api-key"

    init() {
        #if DEBUG
        devEnvKey = loadFromDevEnv()
        #endif
        Task { await checkStoredKey() }
    }

    // MARK: - Stored key restore

    private func checkStoredKey() async {
        guard let key = loadFromKeychain() else {
            state = .unauthenticated
            return
        }
        state = .connecting
        await connect(apiKey: key, saveOnSuccess: false)
    }

    // MARK: - dev.env loader (DEBUG only)

    private func loadFromDevEnv() -> String? {
        // Bundle lives at {project}/MacNativeMCP.app — parent is the project root
        let projectDir = Bundle.main.bundleURL.deletingLastPathComponent()
        let envFile = projectDir.appendingPathComponent("dev.env")
        guard let contents = try? String(contentsOf: envFile, encoding: .utf8) else { return nil }
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("NEXLAYER_API_KEY="), !trimmed.hasPrefix("#") else { continue }
            let value = String(trimmed.dropFirst("NEXLAYER_API_KEY=".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        return nil
    }

    // MARK: - Public

    func authenticate(apiKey: String) async {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .error("API key cannot be empty")
            return
        }
        state = .connecting
        await connect(apiKey: trimmed, saveOnSuccess: true)
    }

    func signOut() {
        deleteFromKeychain()
        currentAPIKey = nil
        state = .unauthenticated
    }

    func retry() {
        state = .unauthenticated
    }

    // MARK: - Connect

    private func connect(apiKey: String, saveOnSuccess: Bool) async {
        let transport = HTTPTransport(url: nexlayerURL, bearerToken: apiKey)
        let client = MCPClient()
        do {
            try await client.connect(transport: transport)
            guard !client.tools.isEmpty else {
                state = .error("Connected but no tools returned — check your API key.")
                return
            }
            if saveOnSuccess { saveToKeychain(apiKey) }
            currentAPIKey = apiKey
            state = .authenticated
        } catch {
            state = .error("Connection failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Keychain

    private func saveToKeychain(_ key: String) {
        guard let data = key.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8)
        else { return nil }
        return key
    }

    private func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
