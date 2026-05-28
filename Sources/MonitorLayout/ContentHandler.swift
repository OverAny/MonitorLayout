import AppKit

/// Per-app adapter that captures and restores window contents (URLs, open
/// folders, cwd, etc.) on top of the geometry that WindowManager handles.
protocol ContentHandler {
    /// One handler may serve a family of apps (e.g. Chromium-based browsers).
    var bundleIds: Set<String> { get }

    /// Called once per visible window during snapshot. Index is the AX
    /// window index (front-to-back). Return nil if there's nothing scriptable
    /// to record for this window.
    func captureContent(for app: NSRunningApplication,
                        axWindowIndex: Int,
                        windowTitle: String?) -> WindowContent?

    /// Called once per app during restore, with all snapshots that belong to
    /// this app, in their captured AX order (front-to-back). The handler is
    /// responsible for ensuring the app ends up with one window per snapshot
    /// holding the right content. WindowManager will then position windows by
    /// AX index. Must invoke completion on the main queue when done.
    func restoreWindows(for app: NSRunningApplication,
                        snapshots: [WindowSnapshot],
                        completion: @escaping () -> Void)
}

final class ContentHandlerRegistry {
    static let shared = ContentHandlerRegistry()

    private var byBundleId: [String: ContentHandler] = [:]

    private init() {
        let handlers: [ContentHandler] = [
            ChromeContentHandler(),
            SafariContentHandler(),
            VSCodeContentHandler(),
            TerminalContentHandler(),
            ITermContentHandler(),
        ]
        for h in handlers {
            for id in h.bundleIds { byBundleId[id] = h }
        }
    }

    func handler(forBundleId bundleId: String) -> ContentHandler? {
        byBundleId[bundleId]
    }
}
