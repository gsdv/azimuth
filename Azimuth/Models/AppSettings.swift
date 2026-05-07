import Foundation
import Observation

@Observable
@MainActor
final class AppSettings {
    private enum Keys {
        static let endpoints = "azimuth.endpoints"
        static let trackingEnabled = "azimuth.trackingEnabled"
        static let deviceId = "azimuth.deviceId"
        static let history = "azimuth.history"
    }

    private let defaults: UserDefaults

    var endpoints: [Endpoint] {
        didSet {
            if let data = try? JSONEncoder().encode(endpoints) {
                defaults.set(data, forKey: Keys.endpoints)
            }
        }
    }

    var trackingEnabled: Bool {
        didSet { defaults.set(trackingEnabled, forKey: Keys.trackingEnabled) }
    }

    var deviceId: String {
        didSet { defaults.set(deviceId, forKey: Keys.deviceId) }
    }

    var history: [SendRecord] {
        didSet {
            let trimmed = Array(history.prefix(50))
            if let data = try? JSONEncoder().encode(trimmed) {
                defaults.set(data, forKey: Keys.history)
            }
        }
    }

    var hasAnyValidEndpoint: Bool {
        endpoints.contains { $0.hasValidURL }
    }

    var hasAnyActiveValidEndpoint: Bool {
        endpoints.contains { $0.isActive && $0.hasValidURL }
    }

    var earliestNextSendDate: Date? {
        let dates = endpoints
            .filter { $0.isActive && $0.hasValidURL }
            .map { $0.nextSendDate() }
        return dates.min()
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Keys.endpoints),
           let decoded = try? JSONDecoder().decode([Endpoint].self, from: data) {
            self.endpoints = decoded
        } else {
            self.endpoints = []
        }
        self.trackingEnabled = defaults.bool(forKey: Keys.trackingEnabled)
        if let existing = defaults.string(forKey: Keys.deviceId), !existing.isEmpty {
            self.deviceId = existing
        } else {
            let new = UUID().uuidString
            defaults.set(new, forKey: Keys.deviceId)
            self.deviceId = new
        }
        if let data = defaults.data(forKey: Keys.history),
           let decoded = try? JSONDecoder().decode([SendRecord].self, from: data) {
            self.history = decoded
        } else {
            self.history = []
        }
    }

    func addEndpoint(_ endpoint: Endpoint) {
        endpoints.append(endpoint)
    }

    func updateEndpoint(_ endpoint: Endpoint) {
        guard let index = endpoints.firstIndex(where: { $0.id == endpoint.id }) else { return }
        endpoints[index] = endpoint
    }

    func deleteEndpoint(id: UUID) {
        endpoints.removeAll { $0.id == id }
        KeychainStore.shared.deleteBearerToken(for: id)
    }

    func endpoint(id: UUID) -> Endpoint? {
        endpoints.first { $0.id == id }
    }

    func bearerToken(for endpointID: UUID) -> String {
        KeychainStore.shared.bearerToken(for: endpointID) ?? ""
    }

    func setBearerToken(_ token: String, for endpointID: UUID) {
        KeychainStore.shared.setBearerToken(token, for: endpointID)
    }

    func recordSend(_ record: SendRecord) {
        history.insert(record, at: 0)
        if record.success {
            if let index = endpoints.firstIndex(where: { $0.id == record.endpointID }) {
                endpoints[index].lastSentDate = record.date
            }
        }
    }
}
