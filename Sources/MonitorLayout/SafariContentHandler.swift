import AppKit

struct SafariContentHandler: ContentHandler {
    let bundleIds: Set<String> = ["com.apple.Safari"]

    func captureContent(for app: NSRunningApplication,
                        axWindowIndex: Int,
                        windowTitle: String?) -> WindowContent? {
        let scriptIndex = axWindowIndex + 1
        let script = """
        tell application "Safari"
            if (count of windows) < \(scriptIndex) then return ""
            set theWindow to window \(scriptIndex)
            set urlList to {}
            repeat with t in tabs of theWindow
                set end of urlList to URL of t
            end repeat
            set AppleScript's text item delimiters to character id 30
            return urlList as text
        end tell
        """
        guard let raw = AppleScriptRunner.runString(script), !raw.isEmpty else { return nil }
        let urls = raw.components(separatedBy: "\u{001E}").filter { !$0.isEmpty }
        guard !urls.isEmpty else { return nil }
        return .browserTabs(activeTabIndex: 0, urls: urls)
    }

    func restoreWindows(for app: NSRunningApplication,
                        snapshots: [WindowSnapshot],
                        completion: @escaping () -> Void) {
        var lines: [String] = []
        lines.append("tell application \"Safari\"")
        lines.append("    activate")
        lines.append("    try")
        lines.append("        close every window")
        lines.append("    end try")

        for snap in snapshots.reversed() {
            guard case .browserTabs(_, let urls) = snap.content, !urls.isEmpty else { continue }
            lines.append("    set newDoc to make new document with properties {URL:\"\(escape(urls[0]))\"}")
            for url in urls.dropFirst() {
                lines.append("    tell front window to set current tab to (make new tab with properties {URL:\"\(escape(url))\"})")
            }
        }
        lines.append("end tell")

        let script = lines.joined(separator: "\n")
        DispatchQueue.global(qos: .userInitiated).async {
            _ = AppleScriptRunner.run(script)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: completion)
        }
    }

    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
