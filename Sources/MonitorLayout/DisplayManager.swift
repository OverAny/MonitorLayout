import AppKit
import CoreGraphics

enum DisplayManager {
    static func currentDisplays() -> [DisplayInfo] {
        NSScreen.screens.compactMap { screen in
            guard let id = screen.displayId else { return nil }
            return DisplayInfo(id: id, frame: screen.frame, isMain: screen == NSScreen.main)
        }
    }

    /// Signature used to recognize "the same monitor setup" across plug/unplug cycles.
    /// We use the sorted set of resolutions because display IDs are not stable across reboots.
    static func signature(for displays: [DisplayInfo]) -> String {
        let parts = displays
            .map { "\(Int($0.frame.width))x\(Int($0.frame.height))" }
            .sorted()
        return "\(parts.count):\(parts.joined(separator: ";"))"
    }

    static func currentSignature() -> String {
        signature(for: currentDisplays())
    }

    /// Pick the display that contains the center of the given frame.
    static func display(containing frame: CGRect, in displays: [DisplayInfo]) -> (DisplayInfo, Int)? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        for (idx, display) in displays.enumerated() where display.frame.contains(center) {
            return (display, idx)
        }
        return displays.first.map { ($0, 0) }
    }

    /// Find the display that best matches a snapshot's original display, falling back
    /// to displayIndex order if the original ID is gone.
    static func matchDisplay(for snapshot: WindowSnapshot, in displays: [DisplayInfo]) -> DisplayInfo? {
        if let exact = displays.first(where: { $0.id == snapshot.displayId }) {
            return exact
        }
        if displays.indices.contains(snapshot.displayIndex) {
            return displays[snapshot.displayIndex]
        }
        return displays.first
    }
}

extension NSScreen {
    var displayId: UInt32? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
