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

### Option A — Open the committed project (no tools needed)

A ready-to-run `mac/NotchReader.xcodeproj` is checked in (Swift 5 mode,
entitlements + `LSUIElement` + `index.html` resource all wired):

```bash
open mac/NotchReader.xcodeproj
```

Pick your Team under *Signing & Capabilities* (free Apple ID is fine), then Run.
If you add/remove source files, either add them in Xcode or regenerate via
Option B.

### Option B — XcodeGen (regenerates the project from project.yml)

```bash
brew install xcodegen          # one-time
cd mac
xcodegen generate              # re-creates NotchReader.xcodeproj
open NotchReader.xcodeproj
```

Select your Personal Team (free Apple ID is fine) under
*Signing & Capabilities*, then Run.

### Option C — Manual Xcode project

1. Xcode → New Project → **macOS → App**. Interface: *(doesn't matter)*,
   Language: **Swift**. Then delete the generated `App.swift`/`ContentView.swift`
   and `Main` storyboard, and remove the `NSMainStoryboardFile`/principal-class
   storyboard entry — the entry point is `@main` on `AppDelegate.swift` (no
   `main.swift`, no storyboard).
2. Drag every file in `mac/NotchReader/` into the project (check *Copy items*
   off if you want them to stay in-repo, on if you prefer Xcode-managed copies).
3. Drag the repo-root `index.html` into the project and add it to the target's
   **Copy Bundle Resources** phase.
   **Set Build Settings → Swift Language Version → Swift 5** (Swift 6 strict
   concurrency throws errors like *"Main actor-isolated conformance … cannot be
   used in nonisolated context"*; the XcodeGen project already pins Swift 5).
4. In the target's Info settings, set **Application is agent (UIElement)** =
   `YES` (this is `LSUIElement` in `Info.plist`).
5. **App Sandbox + WKWebView:** if the template left App Sandbox on, you MUST
   enable **Outgoing Connections (Client)** under the App Sandbox capability —
   otherwise WebKit's helper processes are killed and the strip is blank
   (`errno=34`, GPU/Network/WebContent "Crash"). Either tick that box, point
   `CODE_SIGN_ENTITLEMENTS` at the bundled `NotchReader.entitlements`, or remove
   the App Sandbox capability entirely.
6. Set the deployment target to the macOS on your machine, pick your Team, Run.

## Decisions taken (and how to change them)

- **Location:** a `mac/` folder in this repo rather than a brand-new repository,
  so the wrapper sits next to the engine it bundles and stays one source of
  truth. Easy to split out later.
- **Project generation:** XcodeGen `project.yml` instead of a hand-written
  `.xcodeproj` (a hand-written pbxproj couldn't be validated here and breaks
  easily). Manual path documented above as a fallback.
- **Window level:** ships **aggressive by default** — `CGShieldingWindowLevel()`
  (`FloatLevel.aggressive`), so it's guaranteed over full-screen slideshows out
  of the box. Turn off **"Float above full-screen apps (aggressive level)"** in
  Preferences to drop back to `.statusBar` if it feels intrusive. Both levels
  live in one place: `PrompterWindowController.FloatLevel`.
- **Getting text into the strip:** the strip boots empty; two ways to feed it —
  *Load from Clipboard* (⌘V in the menu) pushes clipboard text straight in; or
  *Open Composer…* opens a normal window hosting the full reader (paste, .txt/
  .pdf/.epub import, sample, calibrate) with a **Send to Strip** button that
  reuses the HTML loader via `Reader.getText()`.
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
| `ComposerWindow.swift` | Full-reader window to load text and send to the strip |
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

## Troubleshooting

- **`Main actor-isolated conformance of 'AppDelegate' … cannot be used in
  nonisolated context`**: the target is building in the Swift 6 language mode.
  Set Build Settings → **Swift Language Version → Swift 5** (the XcodeGen
  project pins this). The `@main`/`@MainActor` entry point also addresses the
  specific delegate-assignment case.
- **`refers to the path "NotchReader", but the capitalization on disk is
  "NotchReader 19-19-52-171"`**: your hand-made `.xcodeproj` got a duplicate /
  timestamped group. Easiest fix is to stop hand-maintaining it — delete the
  `.xcodeproj` and run `xcodegen generate` for a clean, correct project.
- **Blank strip + console spam** `Application does not have permission to
  communicate with network resources. rc=1 : errno=34`, `GPUProcessProxy …
  reason=Crash`, `WebProcessProxy … web process failed to launch`: App Sandbox
  is missing **network.client**. Tick *App Sandbox → Outgoing Connections
  (Client)*, or point `CODE_SIGN_ENTITLEMENTS` at the bundled
  `NotchReader.entitlements`, or remove the App Sandbox capability. The
  `networkd_settings_read_from_file_locked` and `layoutSubtreeIfNeeded` lines
  are harmless noise that disappear once the web process launches.
