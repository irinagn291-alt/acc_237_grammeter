import Foundation

enum WishMsg: Equatable, Sendable {
    case promote(String)
    case askDelete(String)
    case cancelDelete
    case deleteConfirmed(String)
    case returnToHub
}
