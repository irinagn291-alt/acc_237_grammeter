import Foundation

enum WishUpdate {
    static func update(msg: WishMsg, model: WishModel) -> (WishModel, CalibrationCmd) {
        var model = model
        switch msg {
        case .askDelete(let barcode):
            model.pendingDelete = barcode
            return (model, .none)
        case .cancelDelete:
            model.pendingDelete = nil
            return (model, .none)
        case .deleteConfirmed:
            model.pendingDelete = nil
            return (model, .none)
        case .promote, .returnToHub:
            return (model, .none)
        }
    }
}
