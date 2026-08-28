import Foundation

enum PlanMsg: Equatable, Sendable {
    case eat(UUID)
    case askDelete(UUID)
    case cancelDelete
    case deleteConfirmed(UUID)
    case returnToHub
}
