import Foundation
import AuthenticationServices
import CryptoKit
import Security

/// OAuth 2.0 PKCE flow for Nexlayer account linking.
///
/// ## Current state
/// `OAuthManager.config` is `nil` — Nexlayer OAuth client credentials are pending.
/// `AuthManager.openWebSignIn()` falls back to WKWebView until config is set.
///
/// ## Activation
/// When Nexlayer provides OAuth credentials, call:
/// ```swift
/// OAuthManager.configure(
///     clientId: "<client_id>",
///     redirectURI: "nexlayer-mac-native://oauth/callback",
///     authorizationEndpoint: URL(string: "https://app.nexlayer.com/oauth/authorize")!,
///     tokenEndpoint: URL(string: "https://app.nexlayer.com/oauth/token")!,
///     scopes: ["read:credits", "read:referral", "write:coupon"]
/// )
/// ```
///
/// See: project_management/projects/nexlayer-experiments/mac-native-mcp/plans/oauth-credentials-request.md
@MainActor
final class OAuthManager: NSObject {

    // MARK: - Configuration

    struct Config {
        var clientId:               String
        var redirectURI:            String   // e.g. "nexlayer-mac-native://oauth/callback"
        var authorizationEndpoint:  URL      // e.g. https://app.nexlayer.com/oauth/authorize
        var tokenEndpoint:          URL      // e.g. https://app.nexlayer.com/oauth/token
        var scopes:                 [String] // ["read:credits", "read:referral", "write:coupon"]
    }

    /// Set this when Nexlayer provides OAuth credentials.
    /// When nil, AuthManager falls back to WKWebView sign-in.
    static var config: Config?

    static func configure(
        clientId: String,
        redirectURI: String,
        authorizationEndpoint: URL,
        tokenEndpoint: URL,
        scopes: [String] = ["read:credits", "read:referral", "write:coupon"]
    ) {
        config = Config(
            clientId: clientId,
            redirectURI: redirectURI,
            authorizationEndpoint: authorizationEndpoint,
            tokenEndpoint: tokenEndpoint,
            scopes: scopes
        )
    }

    var isConfigured: Bool { OAuthManager.config != nil }

    // MARK: - Token state

    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var tokenExpiry: Date?

    var isTokenValid: Bool {
        guard let token = accessToken, !token.isEmpty else { return false }
        if let expiry = tokenExpiry { return expiry > Date().addingTimeInterval(60) }
        return true
    }

    private let keychainService = "dev.elizaga.mac-native-mcp"
    private let keychainOAuthAccount = "nexlayer-oauth-access-token"
    private let keychainRefreshAccount = "nexlayer-oauth-refresh-token"

    // MARK: - Init / restore

    override init() {
        super.init()
        restoreTokens()
    }

    private func restoreTokens() {
        accessToken  = loadFromKeychain(account: keychainOAuthAccount)
        refreshToken = loadFromKeychain(account: keychainRefreshAccount)
    }

    // MARK: - Authorization (PKCE)

    /// Opens the system browser via ASWebAuthenticationSession and performs PKCE OAuth.
    /// Returns the access token on success.
    func authorize(from anchor: NSWindow? = nil) async throws -> String {
        guard let config = OAuthManager.config else {
            throw OAuthError.notConfigured
        }

        let verifier  = generateCodeVerifier()
        let challenge = codeChallenge(for: verifier)
        let state     = UUID().uuidString

        var components = URLComponents(url: config.authorizationEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id",             value: config.clientId),
            URLQueryItem(name: "redirect_uri",          value: config.redirectURI),
            URLQueryItem(name: "response_type",         value: "code"),
            URLQueryItem(name: "scope",                 value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge",        value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state",                 value: state),
        ]
        guard let authURL = components.url else { throw OAuthError.badConfig }

        let callbackScheme = URL(string: config.redirectURI)!.scheme!
        let contextAnchor  = anchor ?? NSApp.keyWindow

        // System browser opens — user's saved passwords, passkeys, and Face ID work here
        let code = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    continuation.resume(throwing: OAuthError.userCancelled)
                    return
                }
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url = callbackURL,
                      let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                      let codeItem = comps.queryItems?.first(where: { $0.name == "code" }),
                      let returnedState = comps.queryItems?.first(where: { $0.name == "state" })?.value,
                      returnedState == state,
                      let code = codeItem.value
                else {
                    continuation.resume(throwing: OAuthError.invalidCallback)
                    return
                }
                continuation.resume(returning: code)
            }
            session.prefersEphemeralWebBrowserSession = false
            if let anchor = contextAnchor {
                session.presentationContextProvider = PresentationAnchor(window: anchor)
            }
            if !session.start() {
                continuation.resume(throwing: OAuthError.sessionStartFailed)
            }
        }

        return try await exchangeCode(code, verifier: verifier, config: config)
    }

    // MARK: - Refresh

    func refreshAccessToken() async throws -> String {
        guard let config = OAuthManager.config else { throw OAuthError.notConfigured }
        guard let refresh = refreshToken else { throw OAuthError.noRefreshToken }

        var request = URLRequest(url: config.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let params: [String: String] = [
            "grant_type":    "refresh_token",
            "client_id":     config.clientId,
            "refresh_token": refresh,
        ]
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try processTokenResponse(data: data)
    }

    // MARK: - Sign out

    func signOut() {
        accessToken  = nil
        refreshToken = nil
        tokenExpiry  = nil
        deleteFromKeychain(account: keychainOAuthAccount)
        deleteFromKeychain(account: keychainRefreshAccount)
    }

    // MARK: - PKCE helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func codeChallenge(for verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Token exchange

    private func exchangeCode(_ code: String, verifier: String, config: Config) async throws -> String {
        var request = URLRequest(url: config.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let params: [String: String] = [
            "grant_type":    "authorization_code",
            "client_id":     config.clientId,
            "redirect_uri":  config.redirectURI,
            "code":          code,
            "code_verifier": verifier,
        ]
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try processTokenResponse(data: data)
    }

    @discardableResult
    private func processTokenResponse(data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String else {
            throw OAuthError.tokenExchangeFailed(String(data: data, encoding: .utf8) ?? "no body")
        }
        accessToken  = token
        refreshToken = json["refresh_token"] as? String ?? refreshToken
        if let expiresIn = json["expires_in"] as? TimeInterval {
            tokenExpiry = Date().addingTimeInterval(expiresIn)
        }
        saveToKeychain(token, account: keychainOAuthAccount)
        if let refresh = json["refresh_token"] as? String {
            saveToKeychain(refresh, account: keychainRefreshAccount)
        }
        return token
    }

    // MARK: - Keychain

    private func saveToKeychain(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String:   data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadFromKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

private final class PresentationAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {
    let window: NSWindow
    init(window: NSWindow) { self.window = window }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { window }
}

// MARK: - Errors

enum OAuthError: Error, LocalizedError {
    case notConfigured
    case badConfig
    case userCancelled
    case invalidCallback
    case sessionStartFailed
    case noRefreshToken
    case tokenExchangeFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "OAuth credentials not yet configured — pending Nexlayer approval. Using WKWebView fallback."
        case .badConfig:
            return "OAuth config produced an invalid authorization URL."
        case .userCancelled:
            return "Sign-in was cancelled."
        case .invalidCallback:
            return "OAuth callback URL was invalid or state mismatch (possible CSRF)."
        case .sessionStartFailed:
            return "ASWebAuthenticationSession failed to start."
        case .noRefreshToken:
            return "No refresh token available — please sign in again."
        case .tokenExchangeFailed(let body):
            return "Token exchange failed: \(body)"
        }
    }
}
