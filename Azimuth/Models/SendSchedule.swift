import Foundation

enum SendSchedule: Codable, Hashable, Identifiable {
    case hourly
    case every6Hours
    case every12Hours
    case dailyAt(hour: Int, minute: Int)
    case weeklyOn(weekday: Int, hour: Int, minute: Int)

    enum Kind: String, CaseIterable, Identifiable {
        case hourly
        case every6Hours
        case every12Hours
        case daily
        case weekly

        var id: String { rawValue }

        var shortLabel: String {
            switch self {
            case .hourly:       return "1h"
            case .every6Hours:  return "6h"
            case .every12Hours: return "12h"
            case .daily:        return "Daily"
            case .weekly:       return "Weekly"
            }
        }
    }

    var id: String {
        switch self {
        case .hourly:                         return "1h"
        case .every6Hours:                    return "6h"
        case .every12Hours:                   return "12h"
        case .dailyAt(let h, let m):          return "daily-\(h):\(m)"
        case .weeklyOn(let wd, let h, let m): return "weekly-\(wd)-\(h):\(m)"
        }
    }

    var kind: Kind {
        switch self {
        case .hourly:       return .hourly
        case .every6Hours:  return .every6Hours
        case .every12Hours: return .every12Hours
        case .dailyAt:      return .daily
        case .weeklyOn:     return .weekly
        }
    }

    var hour: Int? {
        switch self {
        case .dailyAt(let h, _):    return h
        case .weeklyOn(_, let h, _): return h
        default: return nil
        }
    }

    var minute: Int? {
        switch self {
        case .dailyAt(_, let m):    return m
        case .weeklyOn(_, _, let m): return m
        default: return nil
        }
    }

    var weekday: Int? {
        if case .weeklyOn(let wd, _, _) = self { return wd }
        return nil
    }

    func nextDate(after date: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .hourly:
            return calendar.nextDate(
                after: date,
                matching: DateComponents(minute: 0, second: 0),
                matchingPolicy: .nextTime
            ) ?? date.addingTimeInterval(60 * 60)
        case .every6Hours:
            return SendSchedule.nextHourSlot(after: date, every: 6, calendar: calendar)
                ?? date.addingTimeInterval(6 * 60 * 60)
        case .every12Hours:
            return SendSchedule.nextHourSlot(after: date, every: 12, calendar: calendar)
                ?? date.addingTimeInterval(12 * 60 * 60)
        case .dailyAt(let h, let m):
            var components = DateComponents()
            components.hour = h
            components.minute = m
            return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime) ?? date.addingTimeInterval(24 * 60 * 60)
        case .weeklyOn(let wd, let h, let m):
            var components = DateComponents()
            components.weekday = wd
            components.hour = h
            components.minute = m
            return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime) ?? date.addingTimeInterval(7 * 24 * 60 * 60)
        }
    }

    private static func nextHourSlot(after date: Date, every step: Int, calendar: Calendar) -> Date? {
        var result: Date?
        calendar.enumerateDates(
            startingAfter: date,
            matching: DateComponents(minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) { candidate, _, stop in
            guard let candidate else {
                stop = true
                return
            }
            if calendar.component(.hour, from: candidate) % step == 0 {
                result = candidate
                stop = true
            }
        }
        return result
    }

    var summary: String {
        switch self {
        case .hourly:       return "every hour"
        case .every6Hours:  return "every 6 hours"
        case .every12Hours: return "every 12 hours"
        case .dailyAt(let h, let m):
            return "every day at \(SendSchedule.formatTime(hour: h, minute: m))"
        case .weeklyOn(let wd, let h, let m):
            return "every \(SendSchedule.weekdayName(wd)) at \(SendSchedule.formatTime(hour: h, minute: m))"
        }
    }

    static func formatTime(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func weekdayName(_ weekday: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let symbols = formatter.weekdaySymbols ?? [
            "Sunday", "Monday", "Tuesday", "Wednesday",
            "Thursday", "Friday", "Saturday"
        ]
        let index = ((weekday - 1) % 7 + 7) % 7
        return symbols[index]
    }

    static let defaultDailyHour = 9
    static let defaultDailyMinute = 0
    static let defaultWeeklyWeekday = 2 // Monday in Calendar's 1=Sun convention
}
