import Foundation

enum PlanUpdate {
    static func update(msg: PlanMsg, model: PlanModel) -> (PlanModel, CalibrationCmd) {
        var model = model
        switch msg {
        case .eat:
            return (model, .none)
        case .askDelete(let id):
            model.pendingDelete = id
            return (model, .none)
        case .cancelDelete:
            model.pendingDelete = nil
            return (model, .none)
        case .deleteConfirmed:
            model.pendingDelete = nil
            return (model, .none)
        case .returnToHub:
            return (model, .none)
        }
    }
}
