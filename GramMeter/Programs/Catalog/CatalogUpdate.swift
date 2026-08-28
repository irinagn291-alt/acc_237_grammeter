import Foundation

/// Pure catalog update. Debounce and cancel live in WeighRuntime.
enum CatalogUpdate {
    static func update(msg: CatalogMsg, model: CatalogModel) -> (CatalogModel, CalibrationCmd) {
        var model = model
        switch msg {
        case .setQuery(let query):
            model.query = query
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                model.phase = .idle
                model.hits = []
                model.showSpinner = false
                return (model, .none)
            }
            model.phase = .typing
            model.showSpinner = false
            return (model, .search(trimmed))
        case .searchDue:
            model.phase = .loading
            return (model, .none)
        case .revealSpinner:
            if model.phase == .loading || model.phase == .typing {
                model.showSpinner = true
                model.phase = .loading
            }
            return (model, .none)
        case .finished(let hits, let usedShelf):
            model.hits = hits
            model.usedShelf = usedShelf
            model.showSpinner = false
            model.phase = hits.isEmpty ? .empty : .results
            return (model, .none)
        case .failed:
            let fallback = DemoShelf.matches(query: model.query)
            if fallback.isEmpty {
                model.hits = []
                model.phase = .transport
            } else {
                model.hits = fallback
                model.usedShelf = true
                model.phase = .results
            }
            model.showSpinner = false
            return (model, .none)
        case .retry:
            let trimmed = model.query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return (model, .none) }
            model.phase = .loading
            model.showSpinner = false
            return (model, .search(trimmed))
        case .picked, .returnToHub:
            return (model, .none)
        }
    }
}
