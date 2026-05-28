import Foundation
import CoreGraphics

struct DisplayInfo: Codable, Equatable {
    let id: UInt32
    let frame: CGRect
    let isMain: Bool
}

struct WindowSnapshot: Codable {
    let bundleId: String
    let appName: String
    let executablePath: String?
    let windowTitle: String?
    let displayId: UInt32
    let displayIndex: Int
    let frame: CGRect
    let normalizedFrame: CGRect
    let isMinimized: Bool
}

struct Layout: Codable, Identifiable {
    let id: UUID
    var name: String
    let displays: [DisplayInfo]
    let displaySignature: String
    let windows: [WindowSnapshot]
    let createdAt: Date

    init(id: UUID = UUID(),
         name: String,
         displays: [DisplayInfo],
         displaySignature: String,
         windows: [WindowSnapshot],
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.displays = displays
        self.displaySignature = displaySignature
        self.windows = windows
        self.createdAt = createdAt
    }
}
