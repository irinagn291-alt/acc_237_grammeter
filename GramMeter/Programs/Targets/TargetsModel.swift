import Foundation

/// Elm Model for the Targets spoke (Goals).
struct TargetsModel: Equatable, Sendable {
    var kcalText: String
    var proteinText: String
    var carbsText: String
    var fatText: String
    var askReset: Bool
    var invalid: Bool

    static func from(_ targets: GaugeTargets) -> TargetsModel {
        TargetsModel(
            kcalText: GaugeFormat.energy(targets.kcal),
            proteinText: GaugeFormat.macro(targets.proteinGrams),
            carbsText: GaugeFormat.macro(targets.carbsGrams),
            fatText: GaugeFormat.macro(targets.fatGrams),
            askReset: false,
            invalid: false
        )
    }

    var parsed: GaugeTargets {
        GaugeTargets(
            kcal: GaugeFormat.decimal(from: kcalText) ?? 0,
            proteinGrams: GaugeFormat.decimal(from: proteinText) ?? 0,
            carbsGrams: GaugeFormat.decimal(from: carbsText) ?? 0,
            fatGrams: GaugeFormat.decimal(from: fatText) ?? 0
        )
    }

    var isValid: Bool {
        let value = parsed
        return value.kcal > 0 && value.kcal < 20_000
            && value.proteinGrams > 0 && value.proteinGrams < 2_000
            && value.carbsGrams > 0 && value.carbsGrams < 2_000
            && value.fatGrams > 0 && value.fatGrams < 2_000
    }
}
