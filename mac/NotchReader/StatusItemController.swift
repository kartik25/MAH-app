import Cocoa

/// Menu-bar item: show/hide the strip, play/pause, nudge speed, open
/// Preferences, quit. Mirrors the controls available on the strip itself.
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let playItem = NSMenuItem(title: "Play", action: nil, keyEquivalent: "")

    var onToggleStrip: (() -> Void)?
    var onPlayPause: (() -> Void)?
    var onFaster: (() -> Void)?
    var onSlower: (() -> Void)?
    var onPreferences: (() -> Void)?

    override init() {
        super.init()

        if let button = item.button {
            if let img = NSImage(systemSymbolName: "captions.bubble",
                                 accessibilityDescription: "Reader") {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "📖"
            }
        }

        let menu = NSMenu()
        playItem.target = self
        playItem.action = #selector(playPause)
        menu.addItem(playItem)
        menu.addItem(.separator())
        add(menu, "Faster (+20 wpm)", #selector(faster))
        add(menu, "Slower (−20 wpm)", #selector(slower))
        menu.addItem(.separator())
        add(menu, "Show / Hide Strip", #selector(toggleStrip))
        add(menu, "Preferences…", #selector(preferences), ",")
        menu.addItem(.separator())
        add(menu, "Quit", #selector(quit), "q")
        item.menu = menu
    }

    private func add(_ menu: NSMenu, _ title: String, _ sel: Selector, _ key: String = "") {
        let mi = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        mi.target = self
        menu.addItem(mi)
    }

    func updatePlaying(_ playing: Bool) {
        playItem.title = playing ? "Pause" : "Play"
    }

    @objc private func playPause()  { onPlayPause?() }
    @objc private func faster()     { onFaster?() }
    @objc private func slower()     { onSlower?() }
    @objc private func toggleStrip() { onToggleStrip?() }
    @objc private func preferences() { onPreferences?() }
    @objc private func quit()       { NSApp.terminate(nil) }
}
