import AppKit

struct TerminalContentHandler: ContentHandler {
    let bundleIds: Set<String> = ["com.apple.Terminal"]

    func captureContent(for app: NSRunningApplication,
                        axWindowIndex: Int,
                        windowTitle: String?) -> WindowContent? {
        // Window title usually contains "user@host: /current/working/dir — ...".
        // More reliable: ask Terminal for the tty cwd via AppleScript.
        let scriptIndex = axWindowIndex + 1
        let script = """
        tell application "Terminal"
            if (count of windows) < \(scriptIndex) then return ""
            try
                set theTab to selected tab of window \(scriptIndex)
                set theTty to tty of theTab
                return theTty
            on error
                return ""
            end try
        end tell
        """
        guard let tty = AppleScriptRunner.runString(script), !tty.isEmpty else {
            return cwdFromTitle(windowTitle)
        }
        if let cwd = cwdForTTY(tty) {
            return .workingDirectory(cwd)
        }
        return cwdFromTitle(windowTitle)
    }

    private func cwdForTTY(_ tty: String) -> String? {
        // Find the foreground process for this tty and resolve its cwd via lsof.
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-a", "-d", "cwd", "-Fn", "+E", tty]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run(); task.waitUntilExit()
        } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let out = String(data: data, encoding: .utf8) else { return nil }
        for line in out.split(separator: "\n") where line.hasPrefix("n") {
            return String(line.dropFirst())
        }
        return nil
    }

    private func cwdFromTitle(_ title: String?) -> WindowContent? {
        guard let title = title else { return nil }
        for part in title.components(separatedBy: CharacterSet(charactersIn: " :—-")) {
            if part.hasPrefix("/") || part.hasPrefix("~") {
                return .workingDirectory((part as NSString).expandingTildeInPath)
            }
        }
        return nil
    }

    func restoreWindows(for app: NSRunningApplication,
                        snapshots: [WindowSnapshot],
                        completion: @escaping () -> Void) {
        var lines: [String] = []
        lines.append("tell application \"Terminal\"")
        lines.append("    activate")
        for snap in snapshots {
            guard case .workingDirectory(let path) = snap.content else { continue }
            let escapedPath = path.replacingOccurrences(of: "\"", with: "\\\"")
            lines.append("    do script \"cd \\\"\(escapedPath)\\\" && clear\"")
        }
        lines.append("end tell")
        let script = lines.joined(separator: "\n")
        DispatchQueue.global(qos: .userInitiated).async {
            _ = AppleScriptRunner.run(script)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: completion)
        }
    }
}

struct ITermContentHandler: ContentHandler {
    let bundleIds: Set<String> = ["com.googlecode.iterm2"]

    func captureContent(for app: NSRunningApplication,
                        axWindowIndex: Int,
                        windowTitle: String?) -> WindowContent? {
        let scriptIndex = axWindowIndex + 1
        let script = """
        tell application "iTerm"
            if (count of windows) < \(scriptIndex) then return ""
            try
                set theSession to current session of current tab of window \(scriptIndex)
                return variable named "session.path" of theSession
            on error
                return ""
            end try
        end tell
        """
        guard let cwd = AppleScriptRunner.runString(script), !cwd.isEmpty else { return nil }
        return .workingDirectory(cwd)
    }

    func restoreWindows(for app: NSRunningApplication,
                        snapshots: [WindowSnapshot],
                        completion: @escaping () -> Void) {
        var lines: [String] = []
        lines.append("tell application \"iTerm\"")
        lines.append("    activate")
        for snap in snapshots {
            guard case .workingDirectory(let path) = snap.content else { continue }
            let escapedPath = path.replacingOccurrences(of: "\"", with: "\\\"")
            lines.append("    set newWin to (create window with default profile)")
            lines.append("    tell current session of newWin to write text \"cd \\\"\(escapedPath)\\\" && clear\"")
        }
        lines.append("end tell")
        let script = lines.joined(separator: "\n")
        DispatchQueue.global(qos: .userInitiated).async {
            _ = AppleScriptRunner.run(script)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: completion)
        }
    }
}
