import Foundation
import Combine

/// All user-facing preferences, persisted to `UserDefaults` and published so
/// the SwiftUI Preferences panel and the AppKit side stay in sync. Each change
/// is observed in `AppDelegate` and applied live (speed/size via JS, width/
/// height by resizing the NSWindow, etc.).
final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard

    @Published var wpm: Int            { didSet { d.set(wpm, forKey: "wpm") } }
    @Published var textSize: Double     { didSet { d.set(textSize, forKey: "textSize") } }
    @Published var stripWidth: Double   { didSet { d.set(stripWidth, forKey: "stripWidth") } }
    @Published var stripHeight: Double  { didSet { d.set(stripHeight, forKey: "stripHeight") } }
    @Published var pauseOnHover: Bool   { didSet { d.set(pauseOnHover, forKey: "pauseOnHover") } }
    @Published var clickThrough: Bool   { didSet { d.set(clickThrough, forKey: "clickThrough") } }
    @Published var aggressiveLevel: Bool { didSet { d.set(aggressiveLevel, forKey: "aggressiveLevel") } }

    private init() {
        d.register(defaults: [
            "wpm": 140,            // Present view's natural teleprompter pace
            "textSize": 34,
            "stripWidth": 760,
            "stripHeight": 120,
            "pauseOnHover": true,
            "clickThrough": false,
            // Ship guaranteed-over-full-screen (CGShieldingWindowLevel) by
            // default; toggle down in Preferences if it feels too intrusive.
            "aggressiveLevel": true
        ])
        wpm             = d.integer(forKey: "wpm")
        textSize        = d.double(forKey: "textSize")
        stripWidth      = d.double(forKey: "stripWidth")
        stripHeight     = d.double(forKey: "stripHeight")
        pauseOnHover    = d.bool(forKey: "pauseOnHover")
        clickThrough    = d.bool(forKey: "clickThrough")
        aggressiveLevel = d.bool(forKey: "aggressiveLevel")
    }
}
