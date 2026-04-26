// Private — not exported to public repo
// Reads Claude Code credentials synced by hostside-keychain-poller.
// Source: /Users/jay/Home/projects/tools/hostside-keychain-poller

import Foundation

struct ClaudeCredentials: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresAt: Double?

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt    = "expires_at"
    }

    var isExpired: Bool {
        guard let exp = expiresAt else { return false }
        return Date().timeIntervalSince1970 >= exp
    }
}

@MainActor
final class KeychainCredentialStore: ObservableObject {
    static let shared = KeychainCredentialStore()

    @Published private(set) var credentials: ClaudeCredentials?
    @Published private(set) var lastRefresh: Date?

    private let secretsPath: URL = {
        // Looks for credentials relative to the running app's location first,
        // then falls back to the registered .secrets path.
        let bundleDir = Bundle.main.bundleURL
            .deletingLastPathComponent()  // Contents/MacOS → ..
            .deletingLastPathComponent()  // .app → ..
        let local = bundleDir.appendingPathComponent(".secrets/claude-credentials.json")
        if FileManager.default.fileExists(atPath: local.path) { return local }
        // Fallback: project .secrets/ next to package root
        return URL(fileURLWithPath: "/Users/jay/Home/projects/tools/nexlayer-mac-native-mcp/.secrets/claude-credentials.json")
    }()

    private var pollingTimer: Timer?

    private init() { load() }

    func startPolling(interval: TimeInterval = 30) {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.load() }
        }
    }

    func stopPolling() { pollingTimer?.invalidate() }

    func load() {
        guard let data = try? Data(contentsOf: secretsPath),
              let creds = try? JSONDecoder().decode(ClaudeCredentials.self, from: data)
        else { return }
        credentials = creds
        lastRefresh = Date()
    }

    var bearerToken: String? { credentials?.isExpired == false ? credentials?.accessToken : nil }
}
