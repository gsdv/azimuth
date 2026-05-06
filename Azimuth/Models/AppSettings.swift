import Foundation
import Observation

@Observable
@MainActor
final class AppSettings {
    private enum Keys {
        static let endpointURL = "azimuth.endpointURL"
        static let schedule = "azimuth.schedule"
        static let trackingEnabled = "azimuth.trackingEnabled"
        static let lastSentDate = "azimuth.lastSentDate"
        static let includeBattery = "azimuth.includeBattery"
        static let includeSpeed = "azimuth.includeSpeed"
        static let deviceId = "azimuth.deviceId"
        static let history = "azimuth.history"
    }

    private let defaults: UserDefaults

    var endpointURL: String {
        didSet { defaults.set(endpointURL, forKey: Keys.endpointURL) }
    }

    var schedule: SendSchedule {
        didSet {
            if let data = try? JSONEncoder().encode(schedule) {
                defaults.set(data, forKey: Keys.schedule)
            }
        }
    }

    var trackingEnabled: Bool {
        didSet { defaults.set(trackingEnabled, forKey: Keys.trackingEnabled) }
    }

    var lastSentDate: Date? {
        didSet {
            if let lastSentDate {
                defaults.set(lastSentDate, forKey: Keys.lastSentDate)
            } else {
                defaults.removeObject(forKey: Keys.lastSentDate)
            }
        }
    }

    var includeBattery: Bool {
        didSet { defaults.set(includeBattery, forKey: Keys.includeBattery) }
    }

    var includeSpeed: Bool {
        didSet { defaults.set(includeSpeed, forKey: Keys.includeSpeed) }
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

    var bearerToken: String {
        get { KeychainStore.shared.bearerToken ?? "" }
        set { KeychainStore.shared.bearerToken = newValue.isEmpty ? nil : newValue }
    }

    var hasValidEndpoint: Bool {
        guard let url = URL(string: endpointURL),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host?.isEmpty == false else { return false }
        return true
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.endpointURL = defaults.string(forKey: Keys.endpointURL) ?? ""
        if let data = defaults.data(forKey: Keys.schedule),
           let value = try? JSONDecoder().decode(SendSchedule.self, from: data) {
            self.schedule = value
        } else {
            self.schedule = .hourly
        }
        self.trackingEnabled = defaults.bool(forKey: Keys.trackingEnabled)
        self.lastSentDate = defaults.object(forKey: Keys.lastSentDate) as? Date
        self.includeBattery = defaults.object(forKey: Keys.includeBattery) as? Bool ?? true
        self.includeSpeed = defaults.object(forKey: Keys.includeSpeed) as? Bool ?? true
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

    func recordSend(_ record: SendRecord) {
        history.insert(record, at: 0)
        if record.success {
            lastSentDate = record.date
        }
    }
}
