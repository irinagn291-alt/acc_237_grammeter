import Foundation

/// Tare-aware net mass and unit conversion. Twist logic — unit tested.
enum MassConvert {
    static let gramsPerOunce = 28.349523125

    static func toGrams(_ value: Double, unit: MassUnit, density: Double = 1.0) -> Double {
        switch unit {
        case .gram: value
        case .ounce: value * gramsPerOunce
        case .millilitre: value * density
        }
    }

    static func fromGrams(_ grams: Double, unit: MassUnit, density: Double = 1.0) -> Double {
        switch unit {
        case .gram: grams
        case .ounce: grams / gramsPerOunce
        case .millilitre: density == 0 ? 0 : grams / density
        }
    }

    static func netGrams(tare: Double, gross: Double) -> Double {
        max(0, gross - tare)
    }

    static func netGrams(
        tareDisplay: Double,
        grossDisplay: Double,
        unit: MassUnit,
        density: Double
    ) -> Double {
        let tare = toGrams(tareDisplay, unit: unit, density: density)
        let gross = toGrams(grossDisplay, unit: unit, density: density)
        return netGrams(tare: tare, gross: gross)
    }
}
