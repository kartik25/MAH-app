import Cocoa
import WebKit

/// Hosts the bundled `index.html` in a transparent `WKWebView` and exposes a
/// thin bridge to its `window.Reader` API. No reading/tokenizing/timing lives
/// here — Swift only forwards commands and listens for state.
final class WebController: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    let webView: WKWebView

    /// Fired whenever the page reports playback state (JS -> Swift).
    var onState: ((_ playing: Bool, _ index: Int, _ total: Int) -> Void)?
    /// Fired once the page has finished loading and `window.Reader` exists.
    var onReady: (() -> Void)?

    override init() {
        let config = WKWebViewConfiguration()
        let ucc = WKUserContentController()
        config.userContentController = ucc
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()

        ucc.add(self, name: "state")
        webView.navigationDelegate = self

        // Transparent web view so the clear, borderless window shows through;
        // the HTML itself paints the rounded dark strip in ?chrome=off mode.
        webView.setValue(false, forKey: "drawsBackground")
        webView.wantsLayer = true
        webView.layer?.backgroundColor = NSColor.clear.cgColor
    }

    /// Boot straight into the teleprompter with chrome hidden.
    func loadReader() {
        guard let url = Bundle.main.url(forResource: "index", withExtension: "html") else {
            NSLog("NotchReader: index.html not found in bundle Resources")
            return
        }
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            URLQueryItem(name: "mode", value: "present"),
            URLQueryItem(name: "chrome", value: "off")
        ]
        let bootURL = comps?.url ?? url
        webView.loadFileURL(bootURL, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    // MARK: - Swift -> JS bridge

    private func eval(_ js: String) {
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func setWpm(_ n: Int)        { eval("window.Reader && Reader.setWpm(\(n))") }
    func play()                  { eval("window.Reader && Reader.play()") }
    func pause()                 { eval("window.Reader && Reader.pause()") }
    func toggle()                { eval("window.Reader && Reader.toggle()") }
    func restart()               { eval("window.Reader && Reader.restart()") }
    func step(_ d: Int)          { eval("window.Reader && Reader.step(\(d))") }
    func setTextSize(_ px: Double) { eval("window.Reader && Reader.setTextSize(\(px))") }

    /// Load arbitrary text. JSON-encodes the string so any quotes/newlines are
    /// safely escaped for the JS call.
    func load(text: String) {
        let data = try? JSONSerialization.data(withJSONObject: [text])
        let json = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
        eval("window.Reader && Reader.load((\(json))[0])")
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Belt & suspenders: guarantee present + chrome-off even if WebKit drops
        // the file-URL query string.
        eval("if(window.Reader){Reader.setView('present');Reader.setChrome(true);}")
        onReady?()
    }

    // MARK: - JS -> Swift bridge

    func userContentController(_ uc: WKUserContentController,
                              didReceive message: WKScriptMessage) {
        guard message.name == "state",
              let body = message.body as? [String: Any] else { return }
        let playing = (body["playing"] as? Bool) ?? false
        let index = (body["index"] as? NSNumber)?.intValue ?? 0
        let total = (body["total"] as? NSNumber)?.intValue ?? 0
        onState?(playing, index, total)
    }
}
