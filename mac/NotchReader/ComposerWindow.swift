import Cocoa
import WebKit

/// A normal-chrome composer window that hosts the **full** `index.html` reader
/// (paste, .txt/.pdf/.epub import, sample, calibrate). When you click
/// "Send to Strip" it hands the loaded text to the floating teleprompter via
/// `Reader.getText()` — so all the loading/parsing logic is reused, not
/// duplicated in Swift.
final class ComposerWindowController: NSObject {
    private var window: NSWindow?
    private var webView: WKWebView?

    /// Called with the composed/loaded text when the user sends it to the strip.
    var onSendText: ((String) -> Void)?

    func show() {
        if window == nil { build() }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func build() {
        let wv = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        wv.translatesAutoresizingMaskIntoConstraints = false
        webView = wv

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered, defer: false)
        win.title = "Reader — compose & load"
        win.isReleasedWhenClosed = false

        let container = NSView()
        let bar = NSView()
        bar.translatesAutoresizingMaskIntoConstraints = false

        let send = NSButton(title: "Send to Strip ▸", target: self, action: #selector(sendTapped))
        send.bezelStyle = .rounded
        send.keyEquivalent = "\r"
        send.translatesAutoresizingMaskIntoConstraints = false

        let hint = NSTextField(labelWithString:
            "Paste or open a file above, then send it to the floating strip.")
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: 11)
        hint.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(wv)
        container.addSubview(bar)
        bar.addSubview(send)
        bar.addSubview(hint)

        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: container.topAnchor),
            wv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: bar.topAnchor),

            bar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            bar.heightAnchor.constraint(equalToConstant: 48),

            send.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -12),
            send.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            hint.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 12),
            hint.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
        ])

        win.contentView = container
        window = win
    }

    @objc private func sendTapped() {
        webView?.evaluateJavaScript("window.Reader ? Reader.getText() : ''") { [weak self] result, _ in
            let text = (result as? String) ?? ""
            if !text.isEmpty { self?.onSendText?(text) }
        }
    }
}
