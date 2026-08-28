import Foundation

/// Cached Open Food Facts specimen. Macros stay optional; missing never becomes zero.
struct MassSpecimen: Equatable, Sendable, Identifiable {
    var barcode: String
    var name: String
    var brand: String
    var kcalPer100g: Double?
    var proteinPer100g: Double?
    var carbsPer100g: Double?
    var fatPer100g: Double?
    var imageURL: String?
    var shelfAsset: String?
    var lastRefresh: Date

    var id: String { barcode }

    var hasUsableName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// A logged or planned weigh-in. Totals are computed, never stored.
struct WeighRecord: Equatable, Sendable, Identifiable {
    var id: UUID
    var barcode: String
    var grams: Double
    var slot: WeighSlot
    var day: DayKey
    var isEaten: Bool
}

/// Daily gauge limits written at onboarding and edited on the Targets spoke.
struct GaugeTargets: Equatable, Sendable {
    var kcal: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double

    static let factory = GaugeTargets(kcal: 2200, proteinGrams: 140, carbsGrams: 250, fatGrams: 70)
}

/// A reserved specimen the user intends to buy. Unique by barcode.
struct ReservedSpecimen: Equatable, Sendable, Identifiable {
    var barcode: String
    var added: Date

    var id: String { barcode }
}

enum PortionKind: UInt8, CaseIterable, Sendable, Equatable, Identifiable {
    case slice
    case cup
    case tbsp

    var id: UInt8 { rawValue }

    var label: String {
        switch self {
        case .slice: "Slice"
        case .cup: "Cup"
        case .tbsp: "Tbsp"
        }
    }
}

/// Per-product saved portion mass in grams.
struct PortionPreset: Equatable, Sendable, Identifiable {
    var barcode: String
    var kind: PortionKind
    var grams: Double

    var id: String { "\(barcode).\(kind.rawValue)" }
}

enum MassUnit: UInt8, CaseIterable, Sendable, Equatable, Identifiable {
    case gram
    case ounce
    case millilitre

    var id: UInt8 { rawValue }

    var label: String {
        switch self {
        case .gram: "g"
        case .ounce: "oz"
        case .millilitre: "ml"
        }
    }
}

/// In-memory source of truth. The file on disk is a projection of this value.
struct ScaleArchive: Equatable, Sendable {
    var schemaVersion: UInt16
    var products: [String: MassSpecimen]
    var records: [WeighRecord]
    var wishes: [ReservedSpecimen]
    var presets: [PortionPreset]
    var targets: GaugeTargets
    var onboardingComplete: Bool

    static let empty = ScaleArchive(
        schemaVersion: 1,
        products: [:],
        records: [],
        wishes: [],
        presets: [],
        targets: .factory,
        onboardingComplete: false
    )

    func specimen(for barcode: String) -> MassSpecimen? {
        products[barcode] ?? DemoShelf.specimen(barcode: barcode)
    }

    func eaten(on day: DayKey) -> [WeighRecord] {
        records.filter { $0.day == day && $0.isEaten }
    }

    func planned(from start: DayKey, through end: DayKey) -> [WeighRecord] {
        records.filter { !$0.isEaten && $0.day >= start && $0.day <= end }
    }

    func isWished(_ barcode: String) -> Bool {
        wishes.contains { $0.barcode == barcode }
    }

    func presets(for barcode: String) -> [PortionPreset] {
        presets.filter { $0.barcode == barcode }
    }

    mutating func upsert(_ specimen: MassSpecimen) {
        products[specimen.barcode] = specimen
    }

    mutating func upsertWish(_ barcode: String, added: Date) {
        if let index = wishes.firstIndex(where: { $0.barcode == barcode }) {
            wishes[index].added = added
        } else {
            wishes.append(ReservedSpecimen(barcode: barcode, added: added))
        }
    }

    mutating func upsertPreset(_ preset: PortionPreset) {
        if let index = presets.firstIndex(where: { $0.barcode == preset.barcode && $0.kind == preset.kind }) {
            presets[index] = preset
        } else {
            presets.append(preset)
        }
    }
}

enum DayTotals {
    static func energy(records: [WeighRecord], archive: ScaleArchive) -> Double {
        records.reduce(0) { partial, record in
            partial + (PortionMath.energy(specimen: archive.specimen(for: record.barcode), grams: record.grams) ?? 0)
        }
    }

    static func protein(records: [WeighRecord], archive: ScaleArchive) -> Double? {
        sumMacro(records: records, archive: archive) { $0.proteinPer100g }
    }

    static func carbs(records: [WeighRecord], archive: ScaleArchive) -> Double? {
        sumMacro(records: records, archive: archive) { $0.carbsPer100g }
    }

    static func fat(records: [WeighRecord], archive: ScaleArchive) -> Double? {
        sumMacro(records: records, archive: archive) { $0.fatPer100g }
    }

    private static func sumMacro(
        records: [WeighRecord],
        archive: ScaleArchive,
        pick: (MassSpecimen) -> Double?
    ) -> Double? {
        var total = 0.0
        var sawValue = false
        for record in records {
            guard let specimen = archive.specimen(for: record.barcode) else { continue }
            if let scaled = PortionMath.scale(pick(specimen), grams: record.grams) {
                total += scaled
                sawValue = true
            }
        }
        return sawValue ? total : nil
    }
}
