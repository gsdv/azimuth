import Foundation

struct Endpoint: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var url: String
    var schedule: SendSchedule
    var includeSpeed: Bool
    var includeBattery: Bool
    var isActive: Bool
    var lastSentDate: Date?

    init(
        id: UUID = UUID(),
        name: String = "",
        url: String = "",
        schedule: SendSchedule = .hourly,
        includeSpeed: Bool = true,
        includeBattery: Bool = true,
        isActive: Bool = true,
        lastSentDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.schedule = schedule
        self.includeSpeed = includeSpeed
        self.includeBattery = includeBattery
        self.isActive = isActive
        self.lastSentDate = lastSentDate
    }

    var hasValidURL: Bool {
        guard let parsed = URL(string: url),
              let scheme = parsed.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              parsed.host?.isEmpty == false else { return false }
        return true
    }

    var displayName: String {
        if !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        if let host = URL(string: url)?.host, !host.isEmpty { return host }
        return "Untitled endpoint"
    }

    func nextSendDate(from reference: Date = Date()) -> Date {
        schedule.nextDate(after: lastSentDate ?? reference)
    }

    func shouldSend(now: Date = Date()) -> Bool {
        guard isActive, hasValidURL else { return false }
        guard let last = lastSentDate else { return true }
        return now >= schedule.nextDate(after: last)
    }
}
