import AppKit
import WebKit

/// Opens app.nexlayer.com in a WKWebView window.
/// Shows a status bar with loading/success states.
/// Monitors for the `next-auth.session-token` cookie and calls `onSignIn(token:)` when found.
@MainActor
final class WebSignInWindow: NSObject {

    private var window: NSWindow?
    private var webView: WKWebView?
    private var statusLabel: NSTextField?
    private var checkTimer: Timer?
    var onSignIn: ((String) -> Void)?

    private let nexlayerURL = URL(string: "https://app.nexlayer.com")!
    private let sessionCookieName = "next-auth.session-token"

    // MARK: - Present

    func present(from parentWindow: NSWindow? = nil) {
        let totalH: CGFloat = 700
        let statusBarH: CGFloat = 32
        let webH = totalH - statusBarH - 1  // 1 for separator

        // --- Status bar -------------------------------------------------------
        let statusBar = NSView(frame: NSRect(x: 0, y: 0, width: 860, height: statusBarH))
        statusBar.wantsLayer = true
        statusBar.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor

        let indicator = NSProgressIndicator(frame: NSRect(x: 12, y: 8, width: 16, height: 16))
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.startAnimation(nil)
        statusBar.addSubview(indicator)

        let label = NSTextField(labelWithString: "Loading…")
        label.frame = NSRect(x: 34, y: 8, width: 680, height: 16)
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingMiddle
        statusBar.addSubview(label)
        statusLabel = label

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.controlSize = .small
        cancelBtn.frame = NSRect(x: 786, y: 5, width: 62, height: 22)
        statusBar.addSubview(cancelBtn)

        // --- Separator --------------------------------------------------------
        let sep = NSBox(frame: NSRect(x: 0, y: statusBarH, width: 860, height: 1))
        sep.boxType = .separator

        // --- WebView ----------------------------------------------------------
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()  // share main cookie store
        let wv = WKWebView(frame: NSRect(x: 0, y: statusBarH + 1, width: 860, height: webH), configuration: config)
        wv.navigationDelegate = self
        wv.autoresizingMask = [.width, .height]
        webView = wv

        // --- Container --------------------------------------------------------
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 860, height: totalH))
        container.addSubview(wv)
        container.addSubview(sep)
        container.addSubview(statusBar)

        // --- Window -----------------------------------------------------------
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: totalH),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Link Nexlayer Account"
        win.contentView = container
        win.isReleasedWhenClosed = false
        win.center()
        win.delegate = self
        window = win

        startCookiePolling()
        wv.load(URLRequest(url: nexlayerURL))

        if let parent = parentWindow {
            parent.addChildWindow(win, ordered: .above)
        }
        win.makeKeyAndOrderFront(nil)
    }

    // MARK: - Status helpers

    private func setStatus(_ text: String) {
        statusLabel?.stringValue = text
    }

    // MARK: - Cookie polling

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
        guard let sessionCookie = cookies.first(where: { $0.name == sessionCookieName }),
              !sessionCookie.value.isEmpty else { return }

        stopCookiePolling()
        setStatus("Account linked! ✓ Closing…")

        let token = sessionCookie.value
        // Brief success pause so the user sees the confirmation
        try? await Task.sleep(nanoseconds: 900_000_000)
        onSignIn?(token)
        close()
    }

    private func stopCookiePolling() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    // MARK: - Actions

    @objc private func cancel() { close() }

    func close() {
        stopCookiePolling()
        if let win = window, let parent = win.parent {
            parent.removeChildWindow(win)
        }
        window?.close()
        window = nil
        webView = nil
    }
}

// MARK: - WKNavigationDelegate

extension WebSignInWindow: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        let host = webView.url?.host ?? "nexlayer.com"
        setStatus("Loading \(host)…")
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        setStatus("Sign in to link your Nexlayer account")
    }

    func webView(_ webView: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        setStatus("Load error — \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
        let nsErr = error as NSError
        // Ignore "Frame load interrupted" which fires on successful redirect handling
        guard nsErr.code != NSURLErrorCancelled else { return }
        setStatus("Load error — \(error.localizedDescription)")
    }
}

// MARK: - NSWindowDelegate

extension WebSignInWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // User closed the window manually — stop polling, don't call onSignIn
        stopCookiePolling()
        webView = nil
    }
}
