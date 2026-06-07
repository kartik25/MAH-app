import Cocoa
import ApplicationServices

/// Global + focused play/pause hotkey: ⌃⌥Space.
///
/// - The *local* monitor always works with zero permissions (fires when the
///   strip is the focused window).
/// - The *global* monitor lets you toggle while another app (e.g. Keynote) is
///   frontmost, but macOS only delivers other-app key events to it once the app
///   has **Accessibility** permission (System Settings -> Privacy & Security ->
///   Accessibility). Without that permission, you fall back to the local
///   hotkey + the status-bar menu controls.
final class HotKeyManager {
    var onToggle: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?

    private let keyCode: UInt16 = 49 // Space
    private let required: NSEvent.ModifierFlags = [.control, .option]

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.matches(event) == true { self?.onToggle?() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.matches(event) == true { self?.onToggle?(); return nil }
            return event
        }
    }

    func stop() {
        if let g = globalMonitor { NSEvent.removeMonitor(g) }
        if let l = localMonitor { NSEvent.removeMonitor(l) }
        globalMonitor = nil
        localMonitor = nil
    }

    /// Has Accessibility been granted? (Determines whether the global hotkey
    /// can actually fire while another app is frontmost.)
    var hasAccessibility: Bool { AXIsProcessTrusted() }

    private func matches(_ event: NSEvent) -> Bool {
        guard event.keyCode == keyCode else { return false }
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return mods.isSuperset(of: required)
    }
}
