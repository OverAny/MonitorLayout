import AppKit
import ApplicationServices

enum WindowManager {
    // MARK: Permissions

    @discardableResult
    static func ensureAccessibilityPermission(prompt: Bool = true) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: Snapshot

    static func snapshotAllWindows(displays: [DisplayInfo]) -> [WindowSnapshot] {
        var snapshots: [WindowSnapshot] = []
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular,
                  let bundleId = app.bundleIdentifier else { continue }

            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
                  let windows = value as? [AXUIElement] else { continue }

            for window in windows {
                guard let frame = axFrame(of: window) else { continue }
                let title = axString(of: window, attribute: kAXTitleAttribute)
                let minimized = axBool(of: window, attribute: kAXMinimizedAttribute) ?? false

                let (display, displayIndex) = DisplayManager.display(containing: frame, in: displays)
                    ?? (displays.first ?? DisplayInfo(id: 0, frame: .zero, isMain: true), 0)

                let normalized = normalize(frame: frame, in: display.frame)

                snapshots.append(WindowSnapshot(
                    bundleId: bundleId,
                    appName: app.localizedName ?? bundleId,
                    executablePath: app.bundleURL?.path,
                    windowTitle: title,
                    displayId: display.id,
                    displayIndex: displayIndex,
                    frame: frame,
                    normalizedFrame: normalized,
                    isMinimized: minimized
                ))
            }
        }
        return snapshots
    }

    // MARK: Restore

    static func restore(snapshot: WindowSnapshot, on display: DisplayInfo) -> Bool {
        guard let app = runningApp(forBundleId: snapshot.bundleId) else { return false }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement], !windows.isEmpty else {
            return false
        }

        let window = bestMatch(in: windows, title: snapshot.windowTitle)
        let targetFrame = denormalize(frame: snapshot.normalizedFrame, in: display.frame)
        return setFrame(targetFrame, on: window)
    }

    private static func bestMatch(in windows: [AXUIElement], title: String?) -> AXUIElement {
        guard let title = title, !title.isEmpty else { return windows[0] }
        if let exact = windows.first(where: { axString(of: $0, attribute: kAXTitleAttribute) == title }) {
            return exact
        }
        return windows[0]
    }

    private static func runningApp(forBundleId bundleId: String) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first
    }

    // MARK: AX helpers

    private static func axFrame(of element: AXUIElement) -> CGRect? {
        var posVal: CFTypeRef?
        var sizeVal: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posVal) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeVal) == .success else {
            return nil
        }
        var pos = CGPoint.zero
        var size = CGSize.zero
        // swiftlint:disable force_cast
        AXValueGetValue(posVal as! AXValue, .cgPoint, &pos)
        AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
        // swiftlint:enable force_cast
        return CGRect(origin: pos, size: size)
    }

    private static func setFrame(_ frame: CGRect, on window: AXUIElement) -> Bool {
        var pos = frame.origin
        var size = frame.size
        guard let posValue = AXValueCreate(.cgPoint, &pos),
              let sizeValue = AXValueCreate(.cgSize, &size) else { return false }
        // Set size first then position (some apps clamp position against current size).
        let r1 = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        let r2 = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        let r3 = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        return r1 == .success && r2 == .success && r3 == .success
    }

    private static func axString(of element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func axBool(of element: AXUIElement, attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return (value as? Bool)
    }

    // MARK: Normalization (resolution-independent coords)

    private static func normalize(frame: CGRect, in screen: CGRect) -> CGRect {
        guard screen.width > 0, screen.height > 0 else { return .zero }
        return CGRect(
            x: (frame.origin.x - screen.origin.x) / screen.width,
            y: (frame.origin.y - screen.origin.y) / screen.height,
            width: frame.width / screen.width,
            height: frame.height / screen.height
        )
    }

    private static func denormalize(frame: CGRect, in screen: CGRect) -> CGRect {
        CGRect(
            x: screen.origin.x + frame.origin.x * screen.width,
            y: screen.origin.y + frame.origin.y * screen.height,
            width: frame.width * screen.width,
            height: frame.height * screen.height
        )
    }
}
