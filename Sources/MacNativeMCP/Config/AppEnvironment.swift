import Foundation

/// Runtime environment — controls API endpoints, internal feature gates, and bootstrap behavior.
///
/// ## Selection order
/// 1. `APP_ENV` environment variable (set in run.sh or launch config)
/// 2. Bundle `APP_ENV` key in Info.plist (for Xcode schemes)
/// 3. Falls back to `.production`
///
/// ## Usage
/// ```swift
/// // In release: always production
/// AppEnvironment.current.nexlayerMCPEndpoint
///
/// // Gate internal features
/// if AppEnvironment.current.isInternal { ... }
/// ```
enum AppEnvironment: String, CaseIterable {
    case local       = "local"
    case dev         = "dev"
    case staging     = "staging"
    case production  = "production"

    // MARK: - Current environment

    static var current: AppEnvironment = {
        // 1. Process environment variable
        if let raw = ProcessInfo.processInfo.environment["APP_ENV"],
           let env = AppEnvironment(rawValue: raw.lowercased()) {
            return env
        }
        // 2. Debug builds default to local
        #if DEBUG
        return .local
        #else
        return .production
        #endif
    }()

    // MARK: - Nexlayer MCP endpoint

    var nexlayerMCPEndpoint: URL {
        switch self {
        case .local:
            // Can be overridden via dev.env NEXLAYER_MCP_URL
            if let override = ProcessInfo.processInfo.environment["NEXLAYER_MCP_URL"],
               let url = URL(string: override) {
                return url
            }
            return URL(string: "https://mcp.nexlayer.ai/api/mcp")!
        case .dev:
            return URL(string: "https://mcp.nexlayer.ai/api/mcp")!   // update when dev env exists
        case .staging:
            return URL(string: "https://mcp.nexlayer.ai/api/mcp")!   // update when staging env exists
        case .production:
            return URL(string: "https://mcp.nexlayer.ai/api/mcp")!
        }
    }

    // MARK: - Claude API endpoint

    var claudeAPIEndpoint: URL {
        URL(string: "https://api.anthropic.com")!
    }

    // MARK: - Feature gates

    /// Internal builds get: private server bootstrap, OAuth linking, dev.env prefill.
    var isInternal: Bool {
        switch self {
        case .local, .dev: return true
        case .staging, .production: return false
        }
    }

    /// Friendly display name for Settings UI.
    var displayName: String {
        switch self {
        case .local:      return "Local"
        case .dev:        return "Dev"
        case .staging:    return "Staging"
        case .production: return "Production"
        }
    }

    var displayIcon: String {
        switch self {
        case .local:      return "laptopcomputer"
        case .dev:        return "hammer"
        case .staging:    return "flask"
        case .production: return "checkmark.shield"
        }
    }
}
