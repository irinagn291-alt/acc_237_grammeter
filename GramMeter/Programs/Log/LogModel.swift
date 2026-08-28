import Foundation

/// Elm Model for the Log spoke.
struct LogModel: Equatable, Sendable {
    var day: DayKey
    var followToday: Bool
    var pendingDelete: UUID?

    init(day: DayKey) {
        self.day = day
        self.followToday = true
        self.pendingDelete = nil
    }
}
