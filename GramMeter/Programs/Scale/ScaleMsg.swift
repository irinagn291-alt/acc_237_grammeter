import Foundation

/// Tare-station messages. Vessel mass then gross; net is derived in ScaleModel.
enum TareMsg: Equatable, Sendable {
    case setVessel(String)
    case setGross(String)
}

/// Elm messages for the Weigh spoke, including tare and live scan drops.
enum ScaleMsg: Equatable, Sendable {
    case setGrams(String)
    case tare(TareMsg)
    case setTare(String)
    case setGross(String)
    case setDensity(String)
    case setUnit(MassUnit)
    case applyPreset(Double)
    case savePreset(PortionKind, Double)
    case setSlot(WeighSlot)
    case setEaten(Bool)
    case setFuture(DayKey?)
    case openAssign
    case closeAssign
    case decoded(String)
    case resolveManual
    case setManual(String)
    case resolving
    case revealSpinner
    case resolved(MassSpecimen)
    case resolveFailed(CatalogFault)
    case permission(ScanPermission)
    case addWish(Date)
    case commit(now: Date, id: UUID)
    case gramsRejected
    case askDiscard
    case stay
    case discardAndLeave
    case returnToHub
    case openSettings
}
