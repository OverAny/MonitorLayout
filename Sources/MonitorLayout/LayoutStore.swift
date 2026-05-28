import Foundation

final class LayoutStore {
    static let shared = LayoutStore()

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private(set) var layouts: [Layout] = []

    private init() {
        let fm = FileManager.default
        let appSupport = try! fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                     appropriateFor: nil, create: true)
        let dir = appSupport.appendingPathComponent("MonitorLayout", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("layouts.json")

        self.encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([Layout].self, from: data) else {
            layouts = []
            return
        }
        layouts = decoded
    }

    private func persist() {
        guard let data = try? encoder.encode(layouts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func save(_ layout: Layout) {
        if let idx = layouts.firstIndex(where: { $0.id == layout.id }) {
            layouts[idx] = layout
        } else {
            layouts.append(layout)
        }
        persist()
    }

    func delete(id: UUID) {
        layouts.removeAll { $0.id == id }
        persist()
    }

    func layout(id: UUID) -> Layout? {
        layouts.first { $0.id == id }
    }

    /// Best match by display signature. If multiple match, prefer most recent.
    func bestMatch(forSignature signature: String) -> Layout? {
        layouts
            .filter { $0.displaySignature == signature }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }
}
