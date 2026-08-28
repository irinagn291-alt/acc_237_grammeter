import Foundation

/// Elm Model for the Plan spoke. Horizon is 14 days ahead.
struct PlanModel: Equatable, Sendable {
    var today: DayKey
    var pendingDelete: UUID?

    var horizonEnd: DayKey {
        today.adding(days: 14)
    }
}
