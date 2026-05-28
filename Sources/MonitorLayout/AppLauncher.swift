import AppKit

enum AppLauncher {
    /// Launches an app if it isn't already running. Returns the running app once it's available.
    /// Calls completion on the main queue.
    static func ensureRunning(bundleId: String, executablePath: String?, timeout: TimeInterval = 8.0,
                              completion: @escaping (NSRunningApplication?) -> Void) {
        if let existing = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            completion(existing)
            return
        }

        let url: URL?
        if let path = executablePath {
            url = URL(fileURLWithPath: path)
        } else {
            url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
        }

        guard let appURL = url else {
            completion(nil)
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.addsToRecentItems = false

        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { app, _ in
            if let app = app {
                waitForWindows(of: app, timeout: timeout) {
                    completion(app)
                }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    /// Poll until the app has at least one window, or until the timeout elapses.
    private static func waitForWindows(of app: NSRunningApplication, timeout: TimeInterval,
                                       completion: @escaping () -> Void) {
        let deadline = Date().addingTimeInterval(timeout)
        func check() {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            var value: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value)
            let hasWindow = status == .success && ((value as? [AXUIElement])?.isEmpty == false)
            if hasWindow || Date() >= deadline {
                DispatchQueue.main.async { completion() }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { check() }
            }
        }
        check()
    }
}
