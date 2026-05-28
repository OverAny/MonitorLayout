import AppKit

/// Captures and applies layouts. Coordinates with AppLauncher to relaunch missing apps.
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

    /// Apply a layout: for each snapshot, ensure the app is running, then position its window.
    /// Reports progress and final summary on the main queue.
    static func apply(_ layout: Layout,
                      onProgress: @escaping (_ done: Int, _ total: Int) -> Void = { _, _ in },
                      onComplete: @escaping (_ restored: Int, _ failed: Int) -> Void) {
        let displays = DisplayManager.currentDisplays()
        let snapshots = layout.windows

        // Group by bundle ID so we only launch each app once.
        let byBundle = Dictionary(grouping: snapshots, by: { $0.bundleId })

        var done = 0
        var restored = 0
        var failed = 0
        let total = snapshots.count

        let group = DispatchGroup()
        for (bundleId, group_snaps) in byBundle {
            group.enter()
            let executable = group_snaps.first?.executablePath
            AppLauncher.ensureRunning(bundleId: bundleId, executablePath: executable) { app in
                defer { group.leave() }
                guard app != nil else {
                    failed += group_snaps.count
                    done += group_snaps.count
                    onProgress(done, total)
                    return
                }
                // Give the app a brief moment to finish creating windows.
                for snap in group_snaps {
                    let display = DisplayManager.matchDisplay(for: snap, in: displays)
                        ?? displays.first
                    guard let target = display else {
                        failed += 1
                        done += 1
                        continue
                    }
                    if WindowManager.restore(snapshot: snap, on: target) {
                        restored += 1
                    } else {
                        failed += 1
                    }
                    done += 1
                    onProgress(done, total)
                }
            }
        }

        group.notify(queue: .main) {
            onComplete(restored, failed)
        }
    }
}
