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

    private let nexlayerURL = URL(string: "https://mcp.nexlayer.ai/api/mcp")!
    private let keychainService = "dev.elizaga.mac-native-mcp"
    private let keychainAccount = "nexlayer-api-key"

    init() {
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
