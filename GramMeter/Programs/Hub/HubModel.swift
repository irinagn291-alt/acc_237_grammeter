import Foundation

/// Elm Model for the central hub (Today). Derived totals are not stored.
struct HubModel: Equatable, Sendable {
    var today: DayKey
    var lastAddedID: UUID?
}
