import Cocoa

/// Borderless window that is still allowed to become key, so the focused-only
/// hotkey fallback and text selection work. Always-on-top behaviour comes from
/// the window `level` + `collectionBehavior` set in `PrompterWindowController`.
final class FloatingPanel: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Content view that reports mouse enter/exit for hover-to-pause. Uses an
/// `.inVisibleRect` tracking area so it keeps covering the whole strip after
/// resizes without manual rect bookkeeping.
final class PrompterContentView: NSView {
    weak var hoverDelegate: PrompterHoverDelegate?
    var hoverEnabled = true

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for ta in trackingAreas { removeTrackingArea(ta) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil)
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        if hoverEnabled { hoverDelegate?.prompterMouseEntered() }
    }
    override func mouseExited(with event: NSEvent) {
        if hoverEnabled { hoverDelegate?.prompterMouseExited() }
    }
}

protocol PrompterHoverDelegate: AnyObject {
    func prompterMouseEntered()
    func prompterMouseExited()
}
