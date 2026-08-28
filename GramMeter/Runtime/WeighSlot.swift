import Foundation

/// The four weigh-in stations. Tare is eaten-only; future dates remap it to Weigh-In Three.
enum WeighSlot: UInt8, CaseIterable, Sendable, Equatable, Identifiable {
    case weighInOne
    case weighInTwo
    case weighInThree
    case tare

    var id: UInt8 { rawValue }

    var label: String {
        switch self {
        case .weighInOne: "Weigh-In One"
        case .weighInTwo: "Weigh-In Two"
        case .weighInThree: "Weigh-In Three"
        case .tare: "Tare"
        }
    }

    var assetName: String {
        switch self {
        case .weighInOne: "gmt_SlotWeighInOne"
        case .weighInTwo: "gmt_SlotWeighInTwo"
        case .weighInThree: "gmt_SlotWeighInThree"
        case .tare: "gmt_SlotTare"
        }
    }

    var canPlan: Bool {
        self != .tare
    }

    func remappedForPlanning() -> WeighSlot {
        self == .tare ? .weighInThree : self
    }
}
