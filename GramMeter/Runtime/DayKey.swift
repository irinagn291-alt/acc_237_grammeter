import Foundation

/// Day identity as DateComponents year/month/day. Used in storage, queries and identifiers.
struct DayKey: Hashable, Sendable, Comparable {
    var year: Int
    var month: Int
    var day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(from date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        year = parts.year ?? 1970
        month = parts.month ?? 1
        day = parts.day ?? 1
    }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }

    func date(calendar: Calendar = .current) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        return calendar.date(from: parts) ?? Date(timeIntervalSince1970: 0)
    }

    func adding(days: Int, calendar: Calendar = .current) -> DayKey {
        let shifted = calendar.date(byAdding: .day, value: days, to: date(calendar: calendar)) ?? date(calendar: calendar)
        return DayKey(from: shifted, calendar: calendar)
    }

    var components: DateComponents {
        DateComponents(year: year, month: month, day: day)
    }
}
