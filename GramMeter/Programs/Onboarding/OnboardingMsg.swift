import Foundation

enum OnboardingMsg: Equatable, Sendable {
    case next
    case back
    case setKcal(String)
    case setProtein(String)
    case setCarbs(String)
    case setFat(String)
    case finish
    case skip
}
