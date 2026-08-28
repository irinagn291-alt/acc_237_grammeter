import Foundation

enum TargetsMsg: Equatable, Sendable {
    case setKcal(String)
    case setProtein(String)
    case setCarbs(String)
    case setFat(String)
    case save
    case rerunOnboarding
    case askReset
    case cancelReset
    case resetConfirmed
    case openContact
    case returnToHub
}
