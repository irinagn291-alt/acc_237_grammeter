import Foundation

enum LogUpdate {
    static func update(msg: LogMsg, model: LogModel) -> (LogModel, CalibrationCmd) {
        var model = model
        switch msg {
        case .shiftDay(let delta):
            model.day = model.day.adding(days: delta)
            model.followToday = false
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
