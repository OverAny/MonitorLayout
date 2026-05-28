import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?
    private var debounceWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        _ = WindowManager.ensureAccessibilityPermission(prompt: true)
        menuBar = MenuBarController()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displaysChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func displaysChanged() {
        // Debounce: monitor changes often fire multiple notifications in quick succession.
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.maybeAutoRestore() }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private func maybeAutoRestore() {
        guard Preferences.shared.autoRestore else { return }
        let signature = DisplayManager.currentSignature()
        guard let match = LayoutStore.shared.bestMatch(forSignature: signature) else { return }
        guard WindowManager.ensureAccessibilityPermission(prompt: false) else { return }

        LayoutEngine.apply(match) { restored, _ in
            let n = NSUserNotification()
            n.title = "Restored \(match.name)"
            n.informativeText = "Matched current monitor setup. \(restored) windows restored."
            NSUserNotificationCenter.default.deliver(n)
        }
    }
}
