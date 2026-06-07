# Notch Reader — macOS teleprompter wrapper

A tiny macOS menu-bar app that floats the Reader's **Present** view in an
always-on-top strip near the notch — visible over other apps, including a
full-screen Keynote/PowerPoint slideshow.

**All reading logic stays in `../index.html`.** Swift owns only the window
(position, size, always-on-top, hover-pause, hotkeys, preferences). The same
`index.html` engine is meant to power the planned iPad (Slide Over) and iPhone
(full-screen) wrappers later, with no rewrite.

> ⚠️ **Not yet compiled.** This iteration was authored in a Linux container with
> no Xcode/macOS toolchain, so the Swift target has **not** been built or run
> here, and none of the on-device verification steps below have been executed.
> The code is written to compile and behave per the spec; expect to do the
> verification pass (and small fixups) on a Mac. The `index.html` change *was*
> syntax-checked.

## Build

The reading engine `index.html` lives at the **repo root** (single source of
truth) and is bundled into the app's `Resources/` at build time.

### Option A — XcodeGen (recommended)

```bash
brew install xcodegen          # one-time
cd mac
xcodegen generate              # creates NotchReader.xcodeproj
open NotchReader.xcodeproj
```

Select your Personal Team (free Apple ID is fine) under
*Signing & Capabilities*, then Run.

### Option B — Manual Xcode project

1. Xcode → New Project → **macOS → App**. Interface: *(doesn't matter)*,
   Language: **Swift**. Then delete the generated `App.swift`/`ContentView.swift`
   and `Main` storyboard, and remove the `NSMainStoryboardFile`/principal-class
   storyboard entry — this project uses an AppKit `main.swift` entry point.
2. Drag every file in `mac/NotchReader/` into the project (check *Copy items*
   off if you want them to stay in-repo, on if you prefer Xcode-managed copies).
3. Drag the repo-root `index.html` into the project and add it to the target's
   **Copy Bundle Resources** phase.
4. In the target's Info settings, set **Application is agent (UIElement)** =
   `YES` (this is `LSUIElement` in `Info.plist`).
5. Set the deployment target to the macOS on your machine, pick your Team, Run.

## Decisions taken (and how to change them)

- **Location:** a `mac/` folder in this repo rather than a brand-new repository,
  so the wrapper sits next to the engine it bundles and stays one source of
  truth. Easy to split out later.
- **Project generation:** XcodeGen `project.yml` instead of a hand-written
  `.xcodeproj` (a hand-written pbxproj couldn't be validated here and breaks
  easily). Manual path documented above as a fallback.
- **Window level:** defaults to `.statusBar` (`FloatLevel.normal`). If the strip
  ever vanishes behind a full-screen Keynote slideshow, turn on **"Float above
  full-screen apps (aggressive level)"** in Preferences → escalates to
  `CGShieldingWindowLevel()`. Both live in one place:
  `PrompterWindowController.FloatLevel`.
- **Hotkey:** ⌃⌥Space. Both a *local* monitor (zero-permission, works when the
  strip is focused) and a *global* monitor (works while Keynote is frontmost,
  but only once **Accessibility** is granted). No Carbon dependency.
- **Click-through tension:** mouse events are received by default (so hover-pause
  works). A **Click-through** toggle sets `ignoresMouseEvents = true` for when
  the strip should pass clicks to the app beneath (hover-pause then won't fire,
  by nature).
- **Transparency:** `window.isOpaque = false` + clear background; the web view
  is non-opaque via `setValue(false, forKey:"drawsBackground")`; the HTML
  (`?chrome=off`) paints the rounded dark strip.

## The single web change

`index.html` gained one additive block (everything else unchanged, and it still
works opened directly in a browser):

- Reads URL params: `?mode=present` switches to Present view, `?chrome=off`
  hides all chrome and turns the page transparent with the Present view as a
  rounded dark strip. The app boots `index.html?mode=present&chrome=off`.
- Exposes `window.Reader` for the Swift bridge: `setWpm`, `play`, `pause`,
  `stop`, `toggle`, `restart`, `step`, `load(text)`, `setView`, `setChrome`,
  `setTextSize`, `state()`.
- Reports playback state back to Swift via
  `window.webkit.messageHandlers.state` (no-op in a plain browser).

## File map

| File | Role |
|------|------|
| `main.swift` | AppKit entry point (`NSApplication` + accessory policy) |
| `AppDelegate.swift` | Wires everything; observes `Settings`, applies live |
| `Settings.swift` | `UserDefaults`-backed, `@Published` preferences |
| `WebController.swift` | `WKWebView` host + `window.Reader` bridge |
| `FloatingPanel.swift` | Key-capable borderless window + hover tracking view |
| `PrompterWindowController.swift` | **Core:** level, collectionBehavior, position, drag-clamp |
| `StatusItemController.swift` | Menu-bar item + menu |
| `HotKeyManager.swift` | Global/local ⌃⌥Space play-pause |
| `PreferencesWindow.swift` | SwiftUI Preferences panel |

## Verification checklist (do step 1 first — make or break)

1. **Over full-screen Keynote/PowerPoint Play mode** the strip stays visible, on
   top, scrolling. If not, enable aggressive level (above) and confirm
   `collectionBehavior` has `.fullScreenAuxiliary` + `.canJoinAllSpaces`. Test
   built-in display **and** an external monitor/projector.
2. Always-on-top generally (Safari, Keynote edit, other full-screen apps);
   follows you across Spaces.
3. Notch and non-notch / external screens position correctly.
4. Hover-pause: enter pauses, leave resumes; toggle off works; click-through
   passes clicks beneath.
5. Bridge: Preferences sliders change speed/text size live; width/height resize
   the window; settings persist across relaunch.
6. Hotkey: global ⌃⌥Space works while Keynote is frontmost (grant Accessibility)
   — else the focused-only fallback + menu controls.
7. Offline: launches and plays from bundled `index.html` with no network
   (paste / TXT path; PDF/EPUB import needs network, by design).
8. Free Apple ID (Personal Team) builds and runs locally on this Mac.
