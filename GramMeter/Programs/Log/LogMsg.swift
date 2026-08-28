import Foundation

enum LogMsg: Equatable, Sendable {
    case shiftDay(Int)
    case askDelete(UUID)
    case cancelDelete
    case deleteConfirmed(UUID)
    case returnToHub
}
