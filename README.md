# MonitorLayout

A macOS menu-bar app that remembers where you put your windows.

Save a "layout": the current arrangement of every window across every monitor.
Plug your monitors back in later (dock at your desk, hook up an external,
unplug a screen) and MonitorLayout puts every app back where it was — relaunching
anything that isn't open yet.

## What it does

- **Save layout** — captures every visible window: app, title, monitor, and
  position/size (stored as a fraction of the screen, so it survives resolution
  changes).
- **Auto-restore on monitor change** — listens for display-configuration
  changes. When the set of monitors matches a saved layout, it restores it.
- **Auto-launch missing apps** — if an app from the layout isn't running,
  it launches it and waits for its first window before positioning.
- **Menu-bar only** — no dock icon, no big window. Just an icon in the menu bar.

## Build

Requires macOS 13+ and the Swift toolchain (Xcode or `swift` on the command line).

```sh
./scripts/make-app.sh
open .build/MonitorLayout.app
```

That builds a release binary and wraps it in a `.app` bundle so the
`Info.plist` (which marks the app as a menu-bar-only `LSUIElement`) is honored.

## First run: grant Accessibility access

macOS won't let any app move other apps' windows without permission. On first
launch you'll get a system prompt; if you miss it, open:

**System Settings → Privacy & Security → Accessibility** → add `MonitorLayout.app`.

The menu shows "Accessibility Permission: Granted / Required" so you can tell
at a glance.

## How layout matching works

Layouts are tagged with a **display signature**: the sorted set of monitor
resolutions. So if you save a layout on `{2560x1440, 1920x1080}`, MonitorLayout
will auto-restore it any time those two monitors are connected — regardless of
the underlying display IDs, which change across reboots.

Windows are stored as fractions of their screen (e.g. left half of monitor 2
is `x=0, y=0, w=0.5, h=1`), so a layout you saved on a 4K external will scale
sensibly when you plug in a 1440p one with the same aspect ratio.

## Storage

Layouts are saved as JSON at:

```
~/Library/Application Support/MonitorLayout/layouts.json
```

Safe to back up, edit by hand, or sync.

## Known limits

- Some apps clamp or ignore window positions (Slack's huddle, a few Electron
  apps in fullscreen). You'll see them in the "failed" count after restore.
- Spaces and full-screen apps aren't tracked — fullscreen windows live on their
  own Space and the Accessibility API treats them differently.
- The display signature uses resolution only, not arrangement. If you have two
  identical monitors in different physical positions, MonitorLayout can't tell
  them apart.

## Project layout

```
Sources/MonitorLayout/
  main.swift             # entry point
  AppDelegate.swift      # screen-change observer, debounced auto-restore
  MenuBarController.swift# menu bar UI
  LayoutEngine.swift     # capture + apply orchestration
  WindowManager.swift    # AX API: snapshot/restore window frames
  AppLauncher.swift      # NSWorkspace launching, waits for first window
  DisplayManager.swift   # NSScreen enumeration + signature
  LayoutStore.swift      # JSON persistence
  Preferences.swift      # UserDefaults
  Models.swift           # Layout / WindowSnapshot / DisplayInfo
Resources/Info.plist
scripts/make-app.sh
```
