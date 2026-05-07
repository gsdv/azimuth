import Foundation

actor PendingQueue {
    struct Item: Codable, Identifiable, Equatable {
        let id: UUID
        let endpointID: UUID
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

    func enqueue(endpointID: UUID, body: Data, capturedAt: Date) {
        items.append(Item(id: UUID(), endpointID: endpointID, capturedAt: capturedAt, body: body))
        if items.count > maxItems {
            items.removeFirst(items.count - maxItems)
        }
        persist()
    }

    func snapshot() -> [Item] {
        items
    }

    func snapshot(forEndpoint endpointID: UUID) -> [Item] {
        items.filter { $0.endpointID == endpointID }
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        persist()
    }

    func removeAll(forEndpoint endpointID: UUID) {
        items.removeAll { $0.endpointID == endpointID }
        persist()
    }

    func clear() {
        items.removeAll()
        persist()
    }

    func count() -> Int {
        items.count
    }

    func count(forEndpoint endpointID: UUID) -> Int {
        items.filter { $0.endpointID == endpointID }.count
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
