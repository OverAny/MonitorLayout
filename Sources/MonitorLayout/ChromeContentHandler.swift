import AppKit

/// Handles Chrome and Chromium-derived browsers. They all share the same
/// `windows`/`tabs`/`URL`/`active tab index` AppleScript vocabulary.
struct ChromeContentHandler: ContentHandler {
    let bundleIds: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "company.thebrowser.Browser",   // Arc
        "com.vivaldi.Vivaldi",
        "org.chromium.Chromium",
    ]

    private func appName(for bundleId: String) -> String {
        switch bundleId {
        case "com.google.Chrome":             return "Google Chrome"
        case "com.google.Chrome.canary":      return "Google Chrome Canary"
        case "com.brave.Browser":             return "Brave Browser"
        case "com.microsoft.edgemac":         return "Microsoft Edge"
        case "company.thebrowser.Browser":    return "Arc"
        case "com.vivaldi.Vivaldi":           return "Vivaldi"
        case "org.chromium.Chromium":         return "Chromium"
        default:                              return "Google Chrome"
        }
    }

    func captureContent(for app: NSRunningApplication,
                        axWindowIndex: Int,
                        windowTitle: String?) -> WindowContent? {
        guard let bundleId = app.bundleIdentifier else { return nil }
        let name = appName(for: bundleId)
        // AppleScript indexes are 1-based.
        let scriptIndex = axWindowIndex + 1
        let script = """
        tell application "\(name)"
            if (count of windows) < \(scriptIndex) then return ""
            set theWindow to window \(scriptIndex)
            set active to (active tab index of theWindow)
            set urlList to {}
            repeat with t in tabs of theWindow
                set end of urlList to URL of t
            end repeat
            set AppleScript's text item delimiters to character id 30
            set urlBlob to urlList as text
            return (active as text) & character id 31 & urlBlob
        end tell
        """
        guard let raw = AppleScriptRunner.runString(script), !raw.isEmpty else { return nil }
        let parts = raw.components(separatedBy: "\u{001F}")
        guard parts.count == 2 else { return nil }
        let active = Int(parts[0]) ?? 1
        let urls = parts[1].components(separatedBy: "\u{001E}").filter { !$0.isEmpty }
        guard !urls.isEmpty else { return nil }
        return .browserTabs(activeTabIndex: max(0, active - 1), urls: urls)
    }

    func restoreWindows(for app: NSRunningApplication,
                        snapshots: [WindowSnapshot],
                        completion: @escaping () -> Void) {
        guard let bundleId = app.bundleIdentifier else { completion(); return }
        let name = appName(for: bundleId)

        // Build the AppleScript that closes existing windows then creates new ones
        // in REVERSE snapshot order so that snapshots[0] ends up as front window (1).
        var lines: [String] = []
        lines.append("tell application \"\(name)\"")
        lines.append("    activate")
        lines.append("    try")
        lines.append("        close every window")
        lines.append("    end try")

        for snap in snapshots.reversed() {
            guard case .browserTabs(_, let urls) = snap.content, !urls.isEmpty else { continue }
            lines.append("    set newWin to make new window")
            // First URL goes into the auto-created tab; subsequent URLs become new tabs.
            lines.append("    set URL of active tab of newWin to \"\(escape(urls[0]))\"")
            for url in urls.dropFirst() {
                lines.append("    tell newWin to make new tab with properties {URL:\"\(escape(url))\"}")
            }
        }
        lines.append("end tell")

        let script = lines.joined(separator: "\n")

        DispatchQueue.global(qos: .userInitiated).async {
            _ = AppleScriptRunner.run(script)
            // Browsers need a moment to layout the new windows before AX positioning.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: completion)
        }
    }

    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
