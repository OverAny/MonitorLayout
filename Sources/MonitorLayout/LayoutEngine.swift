import AppKit

/// Captures and applies layouts. Coordinates AppLauncher (launching),
/// ContentHandlerRegistry (rebuilding per-window content), and WindowManager
/// (positioning).
enum LayoutEngine {
    static func capture(named name: String) -> Layout {
        let displays = DisplayManager.currentDisplays()
        let windows = WindowManager.snapshotAllWindows(displays: displays)
        return Layout(
            name: name,
            displays: displays,
            displaySignature: DisplayManager.signature(for: displays),
            windows: windows
        )
    }

    /// Apply a layout: per app — ensure it's running, ask its ContentHandler
    /// (if any) to recreate windows with their saved content, then position
    /// each window via the Accessibility API.
    static func apply(_ layout: Layout,
                      onProgress: @escaping (_ done: Int, _ total: Int) -> Void = { _, _ in },
                      onComplete: @escaping (_ restored: Int, _ failed: Int) -> Void) {
        let displays = DisplayManager.currentDisplays()
        let snapshots = layout.windows
        let byBundle = Dictionary(grouping: snapshots, by: { $0.bundleId })
        let total = snapshots.count

        var done = 0
        var restored = 0
        var failed = 0

        let lock = NSLock()
        func report(restoredDelta: Int = 0, failedDelta: Int = 0, doneDelta: Int) {
            lock.lock()
            restored += restoredDelta
            failed += failedDelta
            done += doneDelta
            let snapshotDone = done
            lock.unlock()
            DispatchQueue.main.async { onProgress(snapshotDone, total) }
        }

        let group = DispatchGroup()
        for (bundleId, snaps) in byBundle {
            group.enter()
            let executable = snaps.first?.executablePath
            AppLauncher.ensureRunning(bundleId: bundleId, executablePath: executable) { app in
                guard let app = app else {
                    report(failedDelta: snaps.count, doneDelta: snaps.count)
                    group.leave()
                    return
                }

                let positionAndDone = {
                    // Re-fetch the running app instance in case the launcher started a fresh one.
                    let current = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first ?? app
                    positionWindows(snaps: snaps, app: current, displays: displays,
                                    onResult: { ok, fail in
                        report(restoredDelta: ok, failedDelta: fail, doneDelta: snaps.count)
                        group.leave()
                    })
                }

                if let handler = ContentHandlerRegistry.shared.handler(forBundleId: bundleId) {
                    handler.restoreWindows(for: app, snapshots: snaps) {
                        positionAndDone()
                    }
                } else {
                    positionAndDone()
                }
            }
        }

        group.notify(queue: .main) {
            onComplete(restored, failed)
        }
    }

    private static func positionWindows(snaps: [WindowSnapshot],
                                        app: NSRunningApplication,
                                        displays: [DisplayInfo],
                                        onResult: @escaping (_ ok: Int, _ fail: Int) -> Void) {
        var ok = 0
        var fail = 0
        for snap in snaps {
            let display = DisplayManager.matchDisplay(for: snap, in: displays) ?? displays.first
            guard let target = display else { fail += 1; continue }
            if WindowManager.restore(snapshot: snap, on: target) {
                ok += 1
            } else {
                fail += 1
            }
        }
        onResult(ok, fail)
    }
}
