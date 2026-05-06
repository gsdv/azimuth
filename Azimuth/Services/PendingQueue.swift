import Foundation

actor PendingQueue {
    struct Item: Codable, Identifiable, Equatable {
        let id: UUID
        let capturedAt: Date
        let body: Data
    }

    private let fileURL: URL
    private let maxItems: Int
    private var items: [Item] = []

    init(filename: String = "pending-sends.json", maxItems: Int = 200) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(filename)
        self.fileURL = url
        self.maxItems = maxItems
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Item].self, from: data) {
            self.items = decoded
        }
    }

    func enqueue(body: Data, capturedAt: Date) {
        items.append(Item(id: UUID(), capturedAt: capturedAt, body: body))
        if items.count > maxItems {
            items.removeFirst(items.count - maxItems)
        }
        persist()
    }

    func snapshot() -> [Item] {
        items
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        persist()
    }

    func clear() {
        items.removeAll()
        persist()
    }

    func count() -> Int {
        items.count
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
