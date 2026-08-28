import Foundation

/// Elm Model for first-run calibration pages.
struct OnboardingModel: Equatable, Sendable {
    var page: Int
    var kcalText: String
    var proteinText: String
    var carbsText: String
    var fatText: String

    static func from(_ targets: GaugeTargets) -> OnboardingModel {
        OnboardingModel(
            page: 0,
            kcalText: GaugeFormat.energy(targets.kcal),
            proteinText: GaugeFormat.macro(targets.proteinGrams),
            carbsText: GaugeFormat.macro(targets.carbsGrams),
            fatText: GaugeFormat.macro(targets.fatGrams)
        )
    }

    var parsed: GaugeTargets {
        let draft = GaugeTargets(
            kcal: GaugeFormat.decimal(from: kcalText) ?? 0,
            proteinGrams: GaugeFormat.decimal(from: proteinText) ?? 0,
            carbsGrams: GaugeFormat.decimal(from: carbsText) ?? 0,
            fatGrams: GaugeFormat.decimal(from: fatText) ?? 0
        )
        if draft.kcal > 0 && draft.proteinGrams > 0 && draft.carbsGrams > 0 && draft.fatGrams > 0 {
            return draft
        }
        return .factory
    }
}
