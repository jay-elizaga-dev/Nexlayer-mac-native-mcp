import Foundation

/// Default Nexlayer deployments seeded on first launch (when servers list is empty).
///
/// **Internal only** — this namespace is private infrastructure and must never ship
/// in production/staging builds. Public users start with an empty server list.
enum NexlayerBootstrap {
    private static let namespace = "amiable-beetle"

    /// Returns the default server list for internal builds, empty for public builds.
    static var defaultServers: [AppState.ServerConfig] {
        guard AppEnvironment.current.isInternal else { return [] }
        return internalServers
    }

    private static var internalServers: [AppState.ServerConfig] {
        let deployments: [(name: String, slug: String)] = [
            ("Gitea",               "gitea-server"),
            ("Uptime Monitor",      "uptime-monitor"),
            ("ETF Bot",             "etf-bot"),
            ("ETF Bot Dev",         "etf-bot-dev-test"),
            ("Emergency Sinlaku",   "emergency-sinlaku"),
            ("Sinlaku Dev",         "emergency-sinlaku-dev"),
            ("Nate Queue API",      "nate-queue-api"),
            ("Content Publisher",   "content-publisher"),
            ("Postiz",              "postiz"),
            ("Shine API",           "shine-api"),
            ("Shine Demo",          "shine-demo"),
            ("Kimi GPU",            "kimi-gpu"),
            ("Object Storage",      "object-storage"),
            ("Gitea Backup",        "gitea-backup"),
            ("Gitea Runner",        "gitea-runner"),
        ]

        return deployments.map { item in
            AppState.ServerConfig(
                name: item.name,
                transport: .http,
                url: "https://\(namespace)-\(item.slug).cloud.nexlayer.ai",
                nexlayerDomain: namespace,
                nexlayerApp: item.slug
            )
        }
    }
}
