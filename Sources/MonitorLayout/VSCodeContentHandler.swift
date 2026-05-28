import AppKit

/// VSCode (and forks like Cursor) don't expose AppleScript for tabs, but the
/// window title is usually `<file> - <folder> - <app>`. We extract the folder
/// and re-open it with `open -a` on restore.
struct VSCodeContentHandler: ContentHandler {
    let bundleIds: Set<String> = [
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.todesktop.230313mzl4w4u92",  // Cursor
        "com.exafunction.windsurf",
    ]

    private func appName(for bundleId: String) -> String {
        switch bundleId {
        case "com.microsoft.VSCode":              return "Visual Studio Code"
        case "com.microsoft.VSCodeInsiders":      return "Visual Studio Code - Insiders"
        case "com.todesktop.230313mzl4w4u92":     return "Cursor"
        case "com.exafunction.windsurf":          return "Windsurf"
        default:                                  return "Visual Studio Code"
        }
    }

    func captureContent(for app: NSRunningApplication,
                        axWindowIndex: Int,
                        windowTitle: String?) -> WindowContent? {
        guard let title = windowTitle, !title.isEmpty else { return nil }
        // Title pattern: "filename - folder - Visual Studio Code" or "folder - Visual Studio Code".
        // We want the segment immediately before the app name.
        let appSuffix = " — " // sometimes em-dash
        let dashSuffix = " - "
        var trimmed = title
        if let r = trimmed.range(of: appSuffix, options: .backwards) { trimmed = String(trimmed[..<r.lowerBound]) }
        if let r = trimmed.range(of: dashSuffix, options: .backwards) {
            trimmed = String(trimmed[..<r.lowerBound])
            // After trimming the app, the last segment is the folder name (not full path).
            if let r2 = trimmed.range(of: dashSuffix, options: .backwards) {
                trimmed = String(trimmed[r2.upperBound...])
            }
        }
        let folderName = trimmed.trimmingCharacters(in: .whitespaces)
        guard !folderName.isEmpty else { return nil }

        // Resolve folder name to absolute path by checking common workspace roots.
        if let absolute = resolveFolderPath(named: folderName) {
            return .folderPath(absolute)
        }
        // Fall back to storing the name; restore will best-effort open it.
        return .folderPath(folderName)
    }

    private func resolveFolderPath(named name: String) -> String? {
        if name.hasPrefix("/") || name.hasPrefix("~") {
            return (name as NSString).expandingTildeInPath
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(name),
            home.appendingPathComponent("Projects").appendingPathComponent(name),
            home.appendingPathComponent("Documents").appendingPathComponent(name),
            home.appendingPathComponent("Developer").appendingPathComponent(name),
            home.appendingPathComponent("Code").appendingPathComponent(name),
            home.appendingPathComponent("src").appendingPathComponent(name),
        ]
        for url in candidates {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                return url.path
            }
        }
        return nil
    }

    func restoreWindows(for app: NSRunningApplication,
                        snapshots: [WindowSnapshot],
                        completion: @escaping () -> Void) {
        guard let bundleId = app.bundleIdentifier else { completion(); return }
        let name = appName(for: bundleId)

        // VSCode opens each folder in a new window. If the folder is already open,
        // it focuses the existing one instead — that's fine for restore.
        let group = DispatchGroup()
        for snap in snapshots {
            guard case .folderPath(let path) = snap.content else { continue }
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.launchPath = "/usr/bin/open"
                task.arguments = ["-a", name, "-n", path]
                do { try task.run(); task.waitUntilExit() } catch { NSLog("VSCode open failed: \(error)") }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: completion)
        }
    }
}
