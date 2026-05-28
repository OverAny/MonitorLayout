import Foundation
import CoreGraphics

struct DisplayInfo: Codable, Equatable {
    let id: UInt32
    let frame: CGRect
    let isMain: Bool
}

/// Per-window app-specific content captured at save time and replayed at restore.
/// Codable as a discriminated union: { "kind": "browserTabs", "urls": [...] }.
enum WindowContent: Codable, Equatable {
    case browserTabs(activeTabIndex: Int, urls: [String])
    case folderPath(String)
    case workingDirectory(String)
    case documents(paths: [String])

    private enum CodingKeys: String, CodingKey {
        case kind, activeTabIndex, urls, path, paths
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .browserTabs(let active, let urls):
            try c.encode("browserTabs", forKey: .kind)
            try c.encode(active, forKey: .activeTabIndex)
            try c.encode(urls, forKey: .urls)
        case .folderPath(let path):
            try c.encode("folderPath", forKey: .kind)
            try c.encode(path, forKey: .path)
        case .workingDirectory(let path):
            try c.encode("workingDirectory", forKey: .kind)
            try c.encode(path, forKey: .path)
        case .documents(let paths):
            try c.encode("documents", forKey: .kind)
            try c.encode(paths, forKey: .paths)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        switch kind {
        case "browserTabs":
            let active = try c.decodeIfPresent(Int.self, forKey: .activeTabIndex) ?? 0
            let urls = try c.decode([String].self, forKey: .urls)
            self = .browserTabs(activeTabIndex: active, urls: urls)
        case "folderPath":
            self = .folderPath(try c.decode(String.self, forKey: .path))
        case "workingDirectory":
            self = .workingDirectory(try c.decode(String.self, forKey: .path))
        case "documents":
            self = .documents(paths: try c.decode([String].self, forKey: .paths))
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: c,
                                                   debugDescription: "Unknown content kind: \(kind)")
        }
    }
}

struct WindowSnapshot: Codable {
    let bundleId: String
    let appName: String
    let executablePath: String?
    let windowTitle: String?
    /// Zero-based index in the app's AX window list at capture time (front-to-back).
    let axWindowIndex: Int
    let displayId: UInt32
    let displayIndex: Int
    let frame: CGRect
    let normalizedFrame: CGRect
    let isMinimized: Bool
    /// App-specific content captured by a ContentHandler (URLs, open folder, cwd, etc.).
    let content: WindowContent?

    init(bundleId: String, appName: String, executablePath: String?, windowTitle: String?,
         axWindowIndex: Int, displayId: UInt32, displayIndex: Int, frame: CGRect,
         normalizedFrame: CGRect, isMinimized: Bool, content: WindowContent?) {
        self.bundleId = bundleId
        self.appName = appName
        self.executablePath = executablePath
        self.windowTitle = windowTitle
        self.axWindowIndex = axWindowIndex
        self.displayId = displayId
        self.displayIndex = displayIndex
        self.frame = frame
        self.normalizedFrame = normalizedFrame
        self.isMinimized = isMinimized
        self.content = content
    }

    private enum CodingKeys: String, CodingKey {
        case bundleId, appName, executablePath, windowTitle, axWindowIndex,
             displayId, displayIndex, frame, normalizedFrame, isMinimized, content
    }

    /// Tolerant decoder: defaults missing fields so layouts saved by earlier
    /// versions of MonitorLayout still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bundleId = try c.decode(String.self, forKey: .bundleId)
        appName = try c.decode(String.self, forKey: .appName)
        executablePath = try c.decodeIfPresent(String.self, forKey: .executablePath)
        windowTitle = try c.decodeIfPresent(String.self, forKey: .windowTitle)
        axWindowIndex = try c.decodeIfPresent(Int.self, forKey: .axWindowIndex) ?? 0
        displayId = try c.decode(UInt32.self, forKey: .displayId)
        displayIndex = try c.decode(Int.self, forKey: .displayIndex)
        frame = try c.decode(CGRect.self, forKey: .frame)
        normalizedFrame = try c.decode(CGRect.self, forKey: .normalizedFrame)
        isMinimized = try c.decodeIfPresent(Bool.self, forKey: .isMinimized) ?? false
        content = try c.decodeIfPresent(WindowContent.self, forKey: .content)
    }
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
