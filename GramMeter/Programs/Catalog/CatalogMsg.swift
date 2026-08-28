import Foundation

enum CatalogMsg: Equatable, Sendable {
    case setQuery(String)
    case searchDue
    case revealSpinner
    case finished([MassSpecimen], usedShelf: Bool)
    case failed(CatalogFault)
    case retry
    case picked(MassSpecimen)
    case returnToHub
}
