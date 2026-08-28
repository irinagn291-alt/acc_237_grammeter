import Foundation

/// Elm messages for the hub. Opening a spoke never navigates to a sibling.
enum HubMsg: Equatable, Sendable {
    case open(Spoke)
    case dismissNotice
    case seedDemo(day: DayKey)
}
