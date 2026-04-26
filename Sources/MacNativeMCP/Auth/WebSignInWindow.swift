import AppKit
import WebKit

/// Opens app.nexlayer.com in a WKWebView window.
/// Monitors for the `next-auth.session-token` cookie that NextAuth.js sets after login.
/// Calls `onSignIn(token:)` when detected, then closes itself.
@MainActor
final class WebSignInWindow: NSObject, WKNavigationDelegate {

    private var window: NSWindow?
    private var webView: WKWebView?
    private var cookieObserver: NSObjectProtocol?
    private var checkTimer: Timer?
    var onSignIn: ((String) -> Void)?

    private let nexlayerURL = URL(string: "https://app.nexlayer.com")!
    private let sessionCookieName = "next-auth.session-token"

    // MARK: - Present

    func present(from parentWindow: NSWindow? = nil) {
        let config = WKWebViewConfiguration()
        // Share cookie store so we can observe it
        config.websiteDataStore = .default()

        let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 840, height: 660), configuration: config)
        wv.navigationDelegate = self
        webView = wv

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 840, height: 660),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Sign in to Nexlayer"
        win.contentView = wv
        win.isReleasedWhenClosed = false
        win.center()
        window = win

        // Start cookie monitoring
        startCookiePolling()

        wv.load(URLRequest(url: nexlayerURL))

        if let parent = parentWindow {
            parent.addChildWindow(win, ordered: .above)
        }
        win.makeKeyAndOrderFront(nil)
    }

    // MARK: - Cookie polling

    /// Poll the WKHTTPCookieStore every second looking for the session token.
    /// WKHTTPCookieStore observers fire on background threads and can be unreliable,
    /// so polling is more robust here.
    private func startCookiePolling() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkForSessionCookie()
            }
        }
    }

    private func checkForSessionCookie() async {
        guard let wv = webView else { return }
        let cookies = await wv.configuration.websiteDataStore.httpCookieStore.allCookies()
        guard let sessionCookie = cookies.first(where: { $0.name == sessionCookieName }) else { return }

        let token = sessionCookie.value
        guard !token.isEmpty else { return }

        stopCookiePolling()
        onSignIn?(token)
        close()
    }

    private func stopCookiePolling() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    // MARK: - Close

    func close() {
        stopCookiePolling()
        window?.close()
        window = nil
        webView = nil
    }
}
