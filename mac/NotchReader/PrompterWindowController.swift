import Cocoa

/// Owns the floating notch strip window: position, size, always-on-top level,
/// collection behaviour, drag-clamping and hover forwarding. This is the core
/// of the wrapper — verify step 1 (over full-screen Keynote) against this file.
final class PrompterWindowController: NSObject, PrompterHoverDelegate {

    /// The window level lives in ONE place so it's trivial to bump while
    /// testing against a full-screen Keynote slideshow.
    enum FloatLevel {
        /// Above normal windows and the menu bar. Try this first.
        static let normal = NSWindow.Level.statusBar
        /// Above another app's full-screen space (Keynote/PowerPoint Play
        /// mode). `CGShieldingWindowLevel()` is what the menu bar / system
        /// overlays use. If `.statusBar` ever disappears over a slideshow,
        /// flip "aggressive level" on in Preferences to use this.
        static let aggressive = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
    }

    let window: FloatingPanel
    private let content: PrompterContentView
    private let settings = Settings.shared
    private var clamping = false

    /// Hover-to-pause hooks (gated by the preference in `AppDelegate`).
    var onHoverPause: (() -> Void)?
    var onHoverResume: (() -> Void)?

    init(web: WebController) {
        let size = NSSize(width: settings.stripWidth, height: settings.stripHeight)
        window = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered, defer: false)
        content = PrompterContentView(frame: NSRect(origin: .zero, size: size))
        super.init()

        // Transparent window — the HTML paints the rounded strip.
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.ignoresMouseEvents = settings.clickThrough

        // The flags that make it float: .fullScreenAuxiliary lets it sit over
        // another app's full-screen space; .canJoinAllSpaces keeps it as you
        // switch Spaces; .stationary stops it sliding during Space transitions.
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        content.autoresizingMask = [.width, .height]
        content.hoverDelegate = self
        content.hoverEnabled = settings.pauseOnHover

        web.webView.frame = content.bounds
        web.webView.autoresizingMask = [.width, .height]
        content.addSubview(web.webView)
        window.contentView = content

        applyLevel(aggressive: settings.aggressiveLevel)
        reposition()

        NotificationCenter.default.addObserver(
            self, selector: #selector(didMove),
            name: NSWindow.didMoveNotification, object: window)
    }

    // MARK: - Visibility

    func show() { window.orderFrontRegardless() }
    func hide() { window.orderOut(nil) }
    func toggleVisible() { window.isVisible ? hide() : show() }

    // MARK: - Live preference application

    func resize(width: Double? = nil, height: Double? = nil) {
        var frame = window.frame
        let w = CGFloat(width ?? Double(frame.width))
        let h = CGFloat(height ?? Double(frame.height))
        frame.size = NSSize(width: w, height: h)
        window.setFrame(frame, display: true)
        reposition()
    }

    func setClickThrough(_ on: Bool) { window.ignoresMouseEvents = on }
    func setHoverEnabled(_ on: Bool) { content.hoverEnabled = on }

    func applyLevel(aggressive: Bool) {
        window.level = aggressive ? FloatLevel.aggressive : FloatLevel.normal
    }

    // MARK: - Positioning

    /// Park at top-centre of the active screen. On notched MacBooks this lands
    /// just under the notch band (safeAreaInsets.top); on non-notched / external
    /// displays it simply pins to the top edge. Never assumes a notch exists.
    func reposition() {
        guard let screen = NSScreen.main else { return }
        let area = screen.frame
        let w = window.frame.width
        let h = window.frame.height
        var topInset: CGFloat = 0
        if #available(macOS 12.0, *) { topInset = screen.safeAreaInsets.top }
        let x = area.midX - w / 2
        let y = area.maxY - h - max(topInset, 0) - 2
        clamping = true
        window.setFrameOrigin(NSPoint(x: x, y: y))
        clamping = false
    }

    /// After a manual drag, clamp the strip back into the top band so it can't
    /// be lost off-screen. Horizontal movement is preserved.
    @objc private func didMove() {
        guard !clamping, let screen = NSScreen.main else { return }
        let area = screen.frame
        let frame = window.frame
        var origin = frame.origin
        let topY = area.maxY - frame.height - 2
        var changed = false
        if origin.y < topY - 120 || origin.y > topY + 2 { origin.y = topY; changed = true }
        if origin.x < area.minX { origin.x = area.minX; changed = true }
        if origin.x + frame.width > area.maxX { origin.x = area.maxX - frame.width; changed = true }
        if changed {
            clamping = true
            window.setFrameOrigin(origin)
            clamping = false
        }
    }

    // MARK: - PrompterHoverDelegate

    func prompterMouseEntered() { onHoverPause?() }
    func prompterMouseExited()  { onHoverResume?() }
}
