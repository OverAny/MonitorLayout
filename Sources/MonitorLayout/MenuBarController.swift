import AppKit

final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    override init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "MonitorLayout")
            button.toolTip = "MonitorLayout"
        }

        menu.delegate = self
        statusItem.menu = menu
        rebuild()
    }

    func menuWillOpen(_ menu: NSMenu) { rebuild() }

    private func rebuild() {
        menu.removeAllItems()

        let saveItem = NSMenuItem(title: "Save Current Layout…", action: #selector(saveLayout), keyEquivalent: "s")
        saveItem.target = self
        menu.addItem(saveItem)

        menu.addItem(.separator())

        let layouts = LayoutStore.shared.layouts.sorted { $0.createdAt > $1.createdAt }
        if layouts.isEmpty {
            let empty = NSMenuItem(title: "No saved layouts", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            let currentSig = DisplayManager.currentSignature()
            for layout in layouts {
                let title = "\(layout.name)  —  \(layout.displays.count) display\(layout.displays.count == 1 ? "" : "s")"
                let item = NSMenuItem(title: title, action: #selector(restoreLayout(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = layout.id
                if layout.displaySignature == currentSig {
                    item.state = .on
                }
                let submenu = NSMenu()
                let del = NSMenuItem(title: "Delete", action: #selector(deleteLayout(_:)), keyEquivalent: "")
                del.target = self
                del.representedObject = layout.id
                submenu.addItem(del)
                item.submenu = submenu
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let autoItem = NSMenuItem(
            title: "Auto-restore on monitor change",
            action: #selector(toggleAutoRestore),
            keyEquivalent: ""
        )
        autoItem.target = self
        autoItem.state = Preferences.shared.autoRestore ? .on : .off
        menu.addItem(autoItem)

        let permItem = NSMenuItem(
            title: "Accessibility Permission: \(WindowManager.ensureAccessibilityPermission(prompt: false) ? "Granted" : "Required")",
            action: #selector(openAccessibilityPrefs),
            keyEquivalent: ""
        )
        permItem.target = self
        menu.addItem(permItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit MonitorLayout", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    // MARK: Actions

    @objc private func saveLayout() {
        let alert = NSAlert()
        alert.messageText = "Save current layout"
        alert.informativeText = "Give this layout a name (e.g. \"Home Office\", \"Laptop Only\")."
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        let defaultName = "Layout \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))"
        input.stringValue = defaultName
        alert.accessoryView = input
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = input.stringValue.trimmingCharacters(in: .whitespaces)
        let layout = LayoutEngine.capture(named: name.isEmpty ? defaultName : name)
        LayoutStore.shared.save(layout)
        notify(title: "Layout saved", body: "\(layout.windows.count) windows across \(layout.displays.count) display(s).")
    }

    @objc private func restoreLayout(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let layout = LayoutStore.shared.layout(id: id) else { return }
        guard WindowManager.ensureAccessibilityPermission(prompt: true) else {
            notify(title: "Accessibility required", body: "Grant access in System Settings to restore layouts.")
            return
        }
        LayoutEngine.apply(layout) { restored, failed in
            self.notify(title: "Restored \(layout.name)",
                        body: "\(restored) windows restored, \(failed) failed.")
        }
    }

    @objc private func deleteLayout(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        LayoutStore.shared.delete(id: id)
    }

    @objc private func toggleAutoRestore() {
        Preferences.shared.autoRestore.toggle()
    }

    @objc private func openAccessibilityPrefs() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: Notifications

    private func notify(title: String, body: String) {
        let n = NSUserNotification()
        n.title = title
        n.informativeText = body
        NSUserNotificationCenter.default.deliver(n)
    }
}
