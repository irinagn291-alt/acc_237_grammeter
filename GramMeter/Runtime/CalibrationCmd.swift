import Foundation

/// Side-effect description. Only WeighRuntime executes these; update stays pure.
enum CalibrationCmd: Equatable, Sendable {
    case none
    case batch([CalibrationCmd])
    case persist
    case persistNow
    case search(String)
    case resolve(String)
    case haptic
    case requestCamera
    case startScanner
    case stopScanner
    case openSettings
    case openContact
    case markDemoSeeded
}
