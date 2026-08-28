import Foundation

/// Pure update for the Weigh spoke. Persistence and network are CalibrationCmd only.
enum ScaleUpdate {
    static func update(msg: ScaleMsg, model: ScaleModel) -> (ScaleModel, CalibrationCmd) {
        var model = model
        switch msg {
        case .setGrams(let text):
            model.gramsText = GaugeFormat.sanitizeDecimal(text)
            model.gramsRejected = false
            return (model, .none)
        case .tare(.setVessel(let text)), .setTare(let text):
            model.tareText = GaugeFormat.sanitizeDecimal(text)
            return (model, .none)
        case .tare(.setGross(let text)), .setGross(let text):
            model.grossText = GaugeFormat.sanitizeDecimal(text)
            return (model, .none)
        case .setDensity(let text):
            model.densityText = GaugeFormat.sanitizeDecimal(text)
            return (model, .none)
        case .setUnit(let unit):
            model.unit = unit
            return (model, .none)
        case .applyPreset(let grams):
            model.gramsText = GaugeFormat.mass(MassConvert.fromGrams(grams, unit: model.unit, density: model.density))
            model.tareText = ""
            model.grossText = ""
            return (model, .none)
        case .savePreset:
            return (model, .none)
        case .setSlot(let slot):
            model.slot = slot
            if !model.eatenToday {
                model.slot = slot.remappedForPlanning()
            }
            return (model, .none)
        case .setEaten(let eaten):
            model.eatenToday = eaten
            if !eaten {
                model.slot = model.slot.remappedForPlanning()
                if model.futureDay == nil {
                    model.futureDay = DayKey(from: Date()).adding(days: 1)
                }
            }
            return (model, .none)
        case .setFuture(let day):
            model.futureDay = day
            if day != nil {
                model.eatenToday = false
                model.slot = model.slot.remappedForPlanning()
            }
            return (model, .none)
        case .openAssign:
            model.assignOpen = true
            return (model, .none)
        case .closeAssign:
            model.assignOpen = false
            return (model, .none)
        case .decoded(let raw):
            if model.lastDecoded == raw { return (model, .none) }
            model.lastDecoded = raw
            model.manualCode = raw
            model.resolveState = .loading
            model.showSpinner = false
            model.commitBlocked = true
            return (model, .none)
        case .setManual(let text):
            model.manualCode = text
            return (model, .none)
        case .resolveManual:
            let code = model.manualCode
            guard BarcodeNormalizer.primary(from: code) != nil else {
                model.resolveState = .notFound
                return (model, .none)
            }
            model.resolveState = .loading
            model.showSpinner = false
            model.commitBlocked = true
            return (model, .resolve(code))
        case .resolving:
            model.resolveState = .loading
            model.commitBlocked = true
            return (model, .none)
        case .revealSpinner:
            if model.resolveState == .loading {
                model.showSpinner = true
            }
            return (model, .none)
        case .resolved(let specimen):
            model.specimen = specimen
            model.resolveState = specimen.kcalPer100g == nil ? .missingEnergy : .ready
            model.showSpinner = false
            model.commitBlocked = false
            return (model, .none)
        case .resolveFailed(let fault):
            model.showSpinner = false
            model.commitBlocked = false
            switch fault {
            case .transport: model.resolveState = .offline
            case .notFound: model.resolveState = .notFound
            case .malformed: model.resolveState = .malformed
            }
            return (model, .none)
        case .permission(let permission):
            model.permission = permission
            if permission == .unknown { return (model, .requestCamera) }
            if permission == .allowed { return (model, .startScanner) }
            return (model, .none)
        case .addWish:
            return (model, .none)
        case .commit:
            model.commitBlocked = true
            return (model, .none)
        case .gramsRejected:
            model.gramsRejected = true
            model.commitBlocked = false
            return (model, .none)
        case .askDiscard:
            model.askDiscard = true
            return (model, .none)
        case .stay:
            model.askDiscard = false
            return (model, .none)
        case .discardAndLeave:
            return (model, .none)
        case .returnToHub:
            return (model, .none)
        case .openSettings:
            return (model, .openSettings)
        }
    }
}
