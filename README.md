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
- **Per-window content** — for supported apps, also captures *what's inside*
  each window:
  - **Chrome / Brave / Edge / Arc / Vivaldi / Chromium**: each window's full
    tab list + active tab.
  - **Safari**: each window's full tab list.
  - **VSCode / Cursor / Windsurf**: the open folder per window.
  - **Terminal**: per-window working directory.
  - **iTerm2**: per-window working directory.
- **Auto-restore on monitor change** — listens for display-configuration
  changes. When the set of monitors matches a saved layout, it restores it.
- **Auto-launch missing apps** — if an app from the layout isn't running,
  it launches it and waits for its first window before positioning.
- **Menu-bar only** — no dock icon, no big window. Just an icon in the menu bar.

## Build & install

Requires macOS 13+ and the Swift toolchain (Xcode or `xcode-select --install`
for command-line tools).

```sh
./scripts/install.sh
```

That builds, ad-hoc signs, and copies `MonitorLayout.app` to `/Applications`,
so it shows up in Launchpad, Spotlight (`⌘Space` → "MonitorLayout"), and is
draggable to your Dock.

If you only want to build without installing system-wide:

```sh
./scripts/make-app.sh
open .build/MonitorLayout.app
```

### Launch at login

Turn on **"Launch at login"** in the menu and macOS will start MonitorLayout
automatically on boot via `SMAppService`.

## First run: grant Accessibility access

macOS won't let any app move other apps' windows without permission. On first
launch you'll get a system prompt; if you miss it, open:

**System Settings → Privacy & Security → Accessibility** → add `MonitorLayout.app`.

The menu shows "Accessibility Permission: Granted / Required" so you can tell
at a glance.

### And Automation access (for content capture)

The first time MonitorLayout asks Chrome (or Safari, Terminal, etc.) for its
tabs/URLs/cwd, macOS will pop up "MonitorLayout wants to control X." Click
**OK**. You can review/revoke these later in:

**System Settings → Privacy & Security → Automation**.

If you decline, MonitorLayout still works — it just won't restore per-window
content for that app.

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
  main.swift                    entry point
  AppDelegate.swift             screen-change observer, debounced auto-restore
  MenuBarController.swift       menu bar UI
  LayoutEngine.swift            capture + apply orchestration
  WindowManager.swift           AX API: snapshot/restore window frames
  AppLauncher.swift             NSWorkspace launching, waits for first window
  DisplayManager.swift          NSScreen enumeration + signature
  LayoutStore.swift             JSON persistence
  Preferences.swift             UserDefaults
  LoginItem.swift               SMAppService launch-at-login toggle
  Models.swift                  Layout / WindowSnapshot / DisplayInfo / WindowContent
  AppleScriptRunner.swift       NSAppleScript wrapper
  ContentHandler.swift          ContentHandler protocol + registry
  ChromeContentHandler.swift    Chrome/Brave/Edge/Arc/Vivaldi/Chromium tabs
  SafariContentHandler.swift    Safari tabs
  VSCodeContentHandler.swift    VSCode/Cursor/Windsurf open-folder
  TerminalContentHandler.swift  Terminal + iTerm2 cwd
Resources/Info.plist
scripts/make-app.sh             build + ad-hoc sign
scripts/install.sh              install to /Applications
```

## Adding a new app handler

1. Create `Sources/MonitorLayout/MyAppContentHandler.swift` conforming to
   `ContentHandler`.
2. Implement `captureContent(...)` (return one of the cases of `WindowContent`)
   and `restoreWindows(...)` (recreate the windows; call completion when done).
3. Register it in `ContentHandler.swift` → `ContentHandlerRegistry.init`.
4. If you need a new content shape (e.g. "playlist + position"), add a case to
   `WindowContent` in `Models.swift`.
