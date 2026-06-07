import Cocoa

// AppKit lifecycle, no storyboard. LSUIElement (Info.plist) makes this a
// menu-bar accessory; we also assert .accessory at runtime to be safe.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
