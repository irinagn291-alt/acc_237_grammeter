import Foundation

enum OnboardingUpdate {
    static func update(msg: OnboardingMsg, model: OnboardingModel) -> (OnboardingModel, CalibrationCmd) {
        var model = model
        switch msg {
        case .next:
            model.page = min(model.page + 1, 3)
            return (model, .none)
        case .back:
            model.page = max(model.page - 1, 0)
            return (model, .none)
        case .setKcal(let text):
            model.kcalText = GaugeFormat.sanitizeDecimal(text)
            return (model, .none)
        case .setProtein(let text):
            model.proteinText = GaugeFormat.sanitizeDecimal(text)
            return (model, .none)
        case .setCarbs(let text):
            model.carbsText = GaugeFormat.sanitizeDecimal(text)
            return (model, .none)
        case .setFat(let text):
            model.fatText = GaugeFormat.sanitizeDecimal(text)
            return (model, .none)
        case .finish, .skip:
            return (model, .none)
        }
    }
}
