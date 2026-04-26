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

    var state: State = .unauthenticated
    var currentAPIKey: String?
    var devEnvKey: String?
    /// Pre-filled key from keychain — offered as default but not auto-connected.
    private(set) var storedKey: String?
    private(set) var nexlayerClient: MCPClient?

    private let nexlayerURL = URL(string: "https://mcp.nexlayer.ai/api/mcp")!
    private let keychainService = "dev.elizaga.mac-native-mcp"
    private let keychainAccount = "nexlayer-api-key"

    init() {
        #if DEBUG
        devEnvKey = loadFromDevEnv()
        #endif
        // Load stored key for pre-fill only — never auto-connect on startup.
        storedKey = loadFromKeychain()
    }

    // MARK: - dev.env loader (DEBUG only)

    private func loadFromDevEnv() -> String? {
        // Check multiple locations so it works from both run.sh and Xcode
        let candidates: [URL] = [
            // run.sh: bundle lives at {project}/MacNativeMCP.app
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("dev.env"),
            // Xcode / anywhere: stable user-level config
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".config/mac-native-mcp/dev.env"),
        ]
        for url in candidates {
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for line in contents.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("NEXLAYER_API_KEY="), !trimmed.hasPrefix("#") else { continue }
                let value = String(trimmed.dropFirst("NEXLAYER_API_KEY=".count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
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
            nexlayerClient = client
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
