import Foundation

enum CatalogPhase: Equatable, Sendable {
    case idle
    case typing
    case loading
    case results
    case empty
    case transport
}

/// Elm Model for the Catalog spoke (search).
struct CatalogModel: Equatable, Sendable {
    var query: String = ""
    var phase: CatalogPhase = .idle
    var hits: [MassSpecimen] = []
    var showSpinner: Bool = false
    var usedShelf: Bool = false
}
