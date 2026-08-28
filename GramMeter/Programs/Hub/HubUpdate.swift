import Foundation

/// Pure hub update. Spoke opens are handled by AppUpdate so the archive stays consistent.
enum HubUpdate {
    static func update(msg: HubMsg, model: HubModel) -> (HubModel, CalibrationCmd) {
        switch msg {
        case .dismissNotice:
            return (model, .none)
        case .open, .seedDemo:
            return (model, .none)
        }
    }
}
