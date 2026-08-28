import Foundation

/// Portion maths. Round only at display; stored values keep full precision.
enum PortionMath {
    static func kcalPer100g(energyKcal: Double?, energyKj: Double?) -> Double? {
        if let energyKcal { return energyKcal }
        if let energyKj { return energyKj / 4.184 }
        return nil
    }

    static func scale(_ per100: Double?, grams: Double) -> Double? {
        guard let per100 else { return nil }
        return per100 * grams / 100
    }

    static func energy(specimen: MassSpecimen?, grams: Double) -> Double? {
        scale(specimen?.kcalPer100g, grams: grams)
    }
}
