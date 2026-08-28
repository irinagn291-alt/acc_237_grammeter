import Foundation

enum TargetsUpdate {
    static func update(msg: TargetsMsg, model: TargetsModel) -> (TargetsModel, CalibrationCmd) {
        var model = model
        switch msg {
        case .setKcal(let text):
            model.kcalText = GaugeFormat.sanitizeDecimal(text)
            model.invalid = false
            return (model, .none)
        case .setProtein(let text):
            model.proteinText = GaugeFormat.sanitizeDecimal(text)
            model.invalid = false
            return (model, .none)
        case .setCarbs(let text):
            model.carbsText = GaugeFormat.sanitizeDecimal(text)
            model.invalid = false
            return (model, .none)
        case .setFat(let text):
            model.fatText = GaugeFormat.sanitizeDecimal(text)
            model.invalid = false
            return (model, .none)
        case .save:
            model.invalid = !model.isValid
            return (model, .none)
        case .askReset:
            model.askReset = true
            return (model, .none)
        case .cancelReset:
            model.askReset = false
            return (model, .none)
        case .rerunOnboarding, .resetConfirmed, .openContact, .returnToHub:
            model.askReset = false
            return (model, .none)
        }
    }
}
