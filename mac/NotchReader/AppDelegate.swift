import Cocoa
import Combine

/// Wires the pieces together: the web controller (engine host), the floating
/// strip window, the status-bar item, Preferences, the global hotkey, and the
/// hover-pause behaviour. Holds no reading logic of its own.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings.shared
    private let web = WebController()
    private lazy var prompter = PrompterWindowController(web: web)
    private let statusItem = StatusItemController()
    private let prefs = PreferencesWindowController()
    private let composer = ComposerWindowController()
    private let hotkeys = HotKeyManager()

    private var cancellables = Set<AnyCancellable>()
    private var playing = false
    private var wasPlayingBeforeHover = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // JS -> Swift: mirror playback state into the menu.
        web.onState = { [weak self] playing, _, _ in
            self?.playing = playing
            self?.statusItem.updatePlaying(playing)
        }
        // Re-apply persisted settings once the page is ready.
        web.onReady = { [weak self] in
            guard let self = self else { return }
            self.web.setWpm(self.settings.wpm)
            self.web.setTextSize(self.settings.textSize)
        }

        // Hover-to-pause: remember whether we were playing, restore on exit.
        prompter.onHoverPause = { [weak self] in
            guard let self = self, self.settings.pauseOnHover else { return }
            self.wasPlayingBeforeHover = self.playing
            if self.playing { self.web.pause() }
        }
        prompter.onHoverResume = { [weak self] in
            guard let self = self, self.settings.pauseOnHover else { return }
            if self.wasPlayingBeforeHover { self.web.play() }
        }

        web.loadReader()
        prompter.show()

        // Status-bar menu.
        statusItem.onToggleStrip = { [weak self] in self?.prompter.toggleVisible() }
        statusItem.onPlayPause   = { [weak self] in self?.web.toggle() }
        statusItem.onFaster      = { [weak self] in self?.bumpWpm(20) }
        statusItem.onSlower      = { [weak self] in self?.bumpWpm(-20) }
        statusItem.onPreferences = { [weak self] in self?.prefs.show() }
        statusItem.onLoadClipboard = { [weak self] in self?.loadFromClipboard() }
        statusItem.onOpenComposer  = { [weak self] in self?.composer.show() }

        // Composer "Send to Strip" -> push text into the floating strip & play.
        composer.onSendText = { [weak self] text in
            guard let self = self else { return }
            self.web.load(text: text)
            self.prompter.show()
            self.web.play()
        }

        bindSettings()

        // Global / focused play-pause hotkey.
        hotkeys.onToggle = { [weak self] in self?.web.toggle() }
        hotkeys.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeys.stop()
    }

    private func bumpWpm(_ delta: Int) {
        settings.wpm = max(60, min(900, settings.wpm + delta))
    }

    private func loadFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        web.load(text: text)
        prompter.show()
        web.play()
    }

    /// Observe each setting and apply its side-effect. `@Published` delivers the
    /// current value to new subscribers immediately, so this also primes the
    /// initial state (web calls are harmless no-ops until the page is ready;
    /// `onReady` re-applies speed/size after load).
    private func bindSettings() {
        settings.$wpm
            .sink { [weak self] in self?.web.setWpm($0) }.store(in: &cancellables)
        settings.$textSize
            .sink { [weak self] in self?.web.setTextSize($0) }.store(in: &cancellables)
        settings.$stripWidth
            .sink { [weak self] in self?.prompter.resize(width: $0) }.store(in: &cancellables)
        settings.$stripHeight
            .sink { [weak self] in self?.prompter.resize(height: $0) }.store(in: &cancellables)
        settings.$clickThrough
            .sink { [weak self] in self?.prompter.setClickThrough($0) }.store(in: &cancellables)
        settings.$pauseOnHover
            .sink { [weak self] in self?.prompter.setHoverEnabled($0) }.store(in: &cancellables)
        settings.$aggressiveLevel
            .sink { [weak self] in self?.prompter.applyLevel(aggressive: $0) }.store(in: &cancellables)
    }
}
