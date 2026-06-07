import Cocoa
import SwiftUI

/// SwiftUI Preferences UI. Bindings write straight into `Settings`, whose
/// `@Published` changes `AppDelegate` observes and applies live.
struct PreferencesView: View {
    @ObservedObject var settings = Settings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(label: Text("Playback").bold()) {
                VStack(spacing: 10) {
                    sliderRow("Speed", value: Binding(
                        get: { Double(settings.wpm) },
                        set: { settings.wpm = Int($0) }),
                        range: 60...900, step: 10, label: "\(settings.wpm) wpm")
                    sliderRow("Text size", value: $settings.textSize,
                        range: 18...72, step: 1, label: "\(Int(settings.textSize)) pt")
                }.padding(8)
            }

            GroupBox(label: Text("Strip size").bold()) {
                VStack(spacing: 10) {
                    sliderRow("Width", value: $settings.stripWidth,
                        range: 320...1400, step: 10, label: "\(Int(settings.stripWidth))")
                    sliderRow("Height", value: $settings.stripHeight,
                        range: 60...360, step: 5, label: "\(Int(settings.stripHeight))")
                }.padding(8)
            }

            GroupBox(label: Text("Behaviour").bold()) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Pause on hover", isOn: $settings.pauseOnHover)
                    Toggle("Click-through (pass clicks to the app beneath)",
                           isOn: $settings.clickThrough)
                    Toggle("Float above full-screen apps (aggressive level)",
                           isOn: $settings.aggressiveLevel)
                }.padding(8)
            }

            Text("Global hotkey: ⌃⌥Space toggles play/pause. To use it while "
                 + "another app is frontmost, grant Accessibility in System "
                 + "Settings › Privacy & Security › Accessibility.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 460)
    }

    private func sliderRow(_ title: String, value: Binding<Double>,
                           range: ClosedRange<Double>, step: Double,
                           label: String) -> some View {
        HStack {
            Text(title).frame(width: 80, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(label).monospacedDigit().frame(width: 72, alignment: .trailing)
        }
    }
}

/// Lazily-created, reused Preferences window.
final class PreferencesWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: PreferencesView())
            let w = NSWindow(contentViewController: host)
            w.title = "Reader Preferences"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            window = w
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
