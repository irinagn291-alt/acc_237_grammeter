import Foundation

enum ResolveState: Equatable, Sendable {
    case idle
    case loading
    case ready
    case missingEnergy
    case notFound
    case offline
    case malformed
}

/// Elm Model for the Weigh spoke — this is the product detail.
struct ScaleModel: Equatable, Sendable {
    var specimen: MassSpecimen?
    var resolveState: ResolveState
    var gramsText: String
    var tareText: String
    var grossText: String
    var unit: MassUnit
    var densityText: String
    var slot: WeighSlot
    var eatenToday: Bool
    var futureDay: DayKey?
    var assignOpen: Bool
    var permission: ScanPermission
    var manualCode: String
    var askDiscard: Bool
    var discardConfirmed: Bool
    var gramsRejected: Bool
    var commitBlocked: Bool
    var showSpinner: Bool
    var lastDecoded: String?

    static let blank = ScaleModel(
        specimen: nil,
        resolveState: .idle,
        gramsText: "",
        tareText: "",
        grossText: "",
        unit: .gram,
        densityText: "1",
        slot: .weighInOne,
        eatenToday: true,
        futureDay: nil,
        assignOpen: false,
        permission: .unknown,
        manualCode: "",
        askDiscard: false,
        discardConfirmed: false,
        gramsRejected: false,
        commitBlocked: false,
        showSpinner: false,
        lastDecoded: nil
    )

    static func loaded(_ specimen: MassSpecimen) -> ScaleModel {
        var model = blank
        model.specimen = specimen
        model.resolveState = specimen.kcalPer100g == nil ? .missingEnergy : .ready
        return model
    }

    var density: Double {
        max(GaugeFormat.decimal(from: densityText) ?? 1, 0.01)
    }

    var tareDisplay: Double? {
        GaugeFormat.decimal(from: tareText)
    }

    var grossDisplay: Double? {
        GaugeFormat.decimal(from: grossText)
    }

    var netGrams: Double? {
        if let tare = tareDisplay, let gross = grossDisplay {
            return MassConvert.netGrams(
                tareDisplay: tare,
                grossDisplay: gross,
                unit: unit,
                density: density
            )
        }
        if let grams = GaugeFormat.decimal(from: gramsText) {
            return MassConvert.toGrams(grams, unit: unit, density: density)
        }
        return nil
    }

    var resolvedGrams: Double? {
        netGrams
    }

    var isDirty: Bool {
        specimen != nil || !gramsText.isEmpty || !tareText.isEmpty || !grossText.isEmpty
    }

}
