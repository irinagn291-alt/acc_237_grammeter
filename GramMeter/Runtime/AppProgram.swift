import Foundation

enum AppRoute: Equatable, Sendable {
    case onboarding
    case hub
    case weigh
    case catalog
    case log
    case plan
    case targets
    case wish
}

enum Spoke: String, Equatable, Sendable, Identifiable {
    case weigh
    case catalog
    case log
    case plan
    case targets
    case wish

    var id: String { rawValue }
}

enum ScanPermission: Equatable, Sendable {
    case unknown
    case allowed
    case denied
    case restricted
    case missingDevice
}

/// Root Elm model. Screen models sit beside the archive; only AppUpdate writes them.
struct AppModel: Equatable, Sendable {
    var archive: ScaleArchive
    var route: AppRoute
    var restoreNotice: String?
    var hub: HubModel
    var scale: ScaleModel
    var catalog: CatalogModel
    var log: LogModel
    var plan: PlanModel
    var targets: TargetsModel
    var onboarding: OnboardingModel
    var wish: WishModel

    static func launch(archive: ScaleArchive, today: DayKey, notice: String?) -> AppModel {
        AppModel(
            archive: archive,
            route: archive.onboardingComplete ? .hub : .onboarding,
            restoreNotice: notice,
            hub: HubModel(today: today),
            scale: ScaleModel.blank,
            catalog: CatalogModel(),
            log: LogModel(day: today),
            plan: PlanModel(today: today),
            targets: TargetsModel.from(archive.targets),
            onboarding: OnboardingModel.from(archive.targets),
            wish: WishModel()
        )
    }
}

/// Root message. Screen messages are nested; time stamps arrive from the runtime.
enum AppMsg: Equatable, Sendable {
    case hub(HubMsg)
    case scale(ScaleMsg)
    case catalog(CatalogMsg)
    case log(LogMsg)
    case plan(PlanMsg)
    case targets(TargetsMsg)
    case onboarding(OnboardingMsg)
    case wish(WishMsg)
    case sceneInactive
    case calendarDayDidChange(DayKey)
}

/// Composes per-screen updates. Archive mutation happens here, never in a View.
enum AppUpdate {
    static func update(msg: AppMsg, model: AppModel) -> (AppModel, CalibrationCmd) {
        var model = model
        switch msg {
        case .sceneInactive:
            return (model, .persistNow)
        case .calendarDayDidChange(let day):
            model.hub.today = day
            if model.log.followToday { model.log.day = day }
            model.plan.today = day
            return (model, .none)
        case .hub(let message):
            return hub(message, model: model)
        case .scale(let message):
            return scale(message, model: model)
        case .catalog(let message):
            return catalog(message, model: model)
        case .log(let message):
            return log(message, model: model)
        case .plan(let message):
            return plan(message, model: model)
        case .targets(let message):
            return targets(message, model: model)
        case .onboarding(let message):
            return onboarding(message, model: model)
        case .wish(let message):
            return wish(message, model: model)
        }
    }

    private static func open(_ spoke: Spoke, model: AppModel) -> (AppModel, CalibrationCmd) {
        var model = model
        switch spoke {
        case .weigh:
            model.scale = ScaleModel.blank
            model.route = .weigh
            return (model, .startScanner)
        case .catalog:
            model.catalog = CatalogModel()
            model.route = .catalog
            return (model, .none)
        case .log:
            model.log = LogModel(day: model.hub.today)
            model.route = .log
            return (model, .none)
        case .plan:
            model.plan = PlanModel(today: model.hub.today)
            model.route = .plan
            return (model, .none)
        case .targets:
            model.targets = TargetsModel.from(model.archive.targets)
            model.route = .targets
            return (model, .none)
        case .wish:
            model.wish = WishModel()
            model.route = .wish
            return (model, .none)
        }
    }

    private static func returnToHub(_ model: AppModel, extra: CalibrationCmd = .none) -> (AppModel, CalibrationCmd) {
        var model = model
        model.route = .hub
        return (model, extra)
    }

    private static func hub(_ message: HubMsg, model: AppModel) -> (AppModel, CalibrationCmd) {
        switch message {
        case .open(let spoke):
            return open(spoke, model: model)
        case .dismissNotice:
            var model = model
            model.restoreNotice = nil
            return (model, .none)
        case .seedDemo(let day):
            var model = model
            model.archive = DemoShelf.seedDay(into: model.archive, day: day)
            return (model, .batch([.persistNow, .markDemoSeeded]))
        }
    }

    private static func scale(_ message: ScaleMsg, model: AppModel) -> (AppModel, CalibrationCmd) {
        if case .returnToHub = message {
            if model.scale.isDirty && !model.scale.discardConfirmed {
                var model = model
                let (next, cmd) = ScaleUpdate.update(msg: .askDiscard, model: model.scale)
                model.scale = next
                return (model, cmd)
            }
            var model = model
            model.route = .hub
            return (model, .stopScanner)
        }
        if case .discardAndLeave = message {
            var model = model
            model.route = .hub
            return (model, .stopScanner)
        }
        if case .commit(let now, let id) = message {
            return commitScale(model: model, now: now, id: id)
        }
        if case .decoded(let raw) = message {
            if model.scale.lastDecoded == raw { return (model, .none) }
            var model = model
            let (next, _) = ScaleUpdate.update(msg: message, model: model.scale)
            model.scale = next
            return (model, .resolve(raw))
        }
        if case .resolved(let specimen) = message {
            var model = model
            let (next, cmd) = ScaleUpdate.update(msg: message, model: model.scale)
            model.scale = next
            model.archive.upsert(specimen)
            return (model, .batch([cmd, .persist]))
        }
        if case .addWish(let now) = message {
            var model = model
            if let specimen = model.scale.specimen {
                model.archive.upsert(specimen)
                model.archive.upsertWish(specimen.barcode, added: now)
                let (next, cmd) = ScaleUpdate.update(msg: message, model: model.scale)
                model.scale = next
                return (model, .batch([cmd, .persist, .haptic]))
            }
            return (model, .none)
        }
        if case .savePreset(let kind, let grams) = message {
            var model = model
            if let barcode = model.scale.specimen?.barcode {
                model.archive.upsertPreset(PortionPreset(barcode: barcode, kind: kind, grams: grams))
            }
            let (next, cmd) = ScaleUpdate.update(msg: message, model: model.scale)
            model.scale = next
            return (model, .batch([cmd, .persist]))
        }
        var model = model
        let (next, cmd) = ScaleUpdate.update(msg: message, model: model.scale)
        model.scale = next
        return (model, cmd)
    }

    private static func commitScale(model: AppModel, now: Date, id: UUID) -> (AppModel, CalibrationCmd) {
        var model = model
        guard let specimen = model.scale.specimen else { return (model, .none) }
        guard let grams = model.scale.resolvedGrams, grams > 0, grams <= 20_000 else {
            let (next, cmd) = ScaleUpdate.update(msg: .gramsRejected, model: model.scale)
            model.scale = next
            return (model, cmd)
        }
        var slot = model.scale.slot
        var day = model.hub.today
        var eaten = model.scale.eatenToday
        if !model.scale.eatenToday {
            let proposed = model.scale.futureDay ?? model.hub.today.adding(days: 1)
            day = proposed > model.hub.today ? proposed : model.hub.today.adding(days: 1)
            eaten = false
            slot = slot.remappedForPlanning()
        }
        model.archive.upsert(specimen)
        model.archive.records.append(
            WeighRecord(id: id, barcode: specimen.barcode, grams: grams, slot: slot, day: day, isEaten: eaten)
        )
        model.hub.lastAddedID = id
        model.route = .hub
        return (model, .batch([.persistNow, .haptic, .stopScanner]))
    }

    private static func catalog(_ message: CatalogMsg, model: AppModel) -> (AppModel, CalibrationCmd) {
        if case .picked(let specimen) = message {
            var model = model
            model.archive.upsert(specimen)
            model.scale = ScaleModel.loaded(specimen)
            model.route = .weigh
            return (model, .batch([.persist, .startScanner]))
        }
        if case .returnToHub = message {
            return returnToHub(model)
        }
        var model = model
        let (next, cmd) = CatalogUpdate.update(msg: message, model: model.catalog)
        model.catalog = next
        return (model, cmd)
    }

    private static func log(_ message: LogMsg, model: AppModel) -> (AppModel, CalibrationCmd) {
        if case .returnToHub = message {
            return returnToHub(model)
        }
        if case .deleteConfirmed(let id) = message {
            var model = model
            model.archive.records.removeAll { $0.id == id }
            let (next, cmd) = LogUpdate.update(msg: message, model: model.log)
            model.log = next
            return (model, .batch([cmd, .persistNow]))
        }
        var model = model
        let (next, cmd) = LogUpdate.update(msg: message, model: model.log)
        model.log = next
        return (model, cmd)
    }

    private static func plan(_ message: PlanMsg, model: AppModel) -> (AppModel, CalibrationCmd) {
        if case .returnToHub = message {
            return returnToHub(model)
        }
        if case .open(let id) = message {
            var model = model
            model.plan.pendingDelete = nil
            if let record = model.archive.records.first(where: { $0.id == id }),
               let specimen = model.archive.specimen(for: record.barcode) {
                model.scale = ScaleModel.loaded(specimen)
                model.route = .weigh
                return (model, .startScanner)
            }
            return (model, .none)
        }
        if case .eat(let id) = message {
            var model = model
            model.plan.pendingDelete = nil
            if let index = model.archive.records.firstIndex(where: { $0.id == id }) {
                model.archive.records[index].isEaten = true
                model.archive.records[index].day = model.hub.today
            }
            return (model, .batch([.persistNow, .haptic]))
        }
        if case .deleteConfirmed(let id) = message {
            var model = model
            model.archive.records.removeAll { $0.id == id }
            return (model, .persistNow)
        }
        var model = model
        let (next, cmd) = PlanUpdate.update(msg: message, model: model.plan)
        model.plan = next
        return (model, cmd)
    }

    private static func targets(_ message: TargetsMsg, model: AppModel) -> (AppModel, CalibrationCmd) {
        if case .returnToHub = message {
            return returnToHub(model)
        }
        if case .save = message {
            var model = model
            let (next, cmd) = TargetsUpdate.update(msg: message, model: model.targets)
            model.targets = next
            if next.isValid {
                model.archive.targets = next.parsed
                return (model, .batch([cmd, .persistNow, .haptic]))
            }
            return (model, cmd)
        }
        if case .rerunOnboarding = message {
            var model = model
            model.onboarding = OnboardingModel.from(model.archive.targets)
            model.route = .onboarding
            return (model, .none)
        }
        if case .resetConfirmed = message {
            var model = model
            let keptOnboarding = model.archive.onboardingComplete
            model.archive = .empty
            model.archive.onboardingComplete = keptOnboarding
            model.targets = TargetsModel.from(model.archive.targets)
            model.restoreNotice = "All weigh-ins were cleared."
            return (model, .persistNow)
        }
        if case .openContact = message {
            return (model, .openContact)
        }
        var model = model
        let (next, cmd) = TargetsUpdate.update(msg: message, model: model.targets)
        model.targets = next
        return (model, cmd)
    }

    private static func onboarding(_ message: OnboardingMsg, model: AppModel) -> (AppModel, CalibrationCmd) {
        if case .finish = message {
            var model = model
            let (next, cmd) = OnboardingUpdate.update(msg: message, model: model.onboarding)
            model.onboarding = next
            model.archive.targets = next.parsed
            model.archive.onboardingComplete = true
            model.targets = TargetsModel.from(model.archive.targets)
            model.route = .hub
            return (model, .batch([cmd, .persistNow, .haptic]))
        }
        if case .skip = message {
            var model = model
            model.archive.targets = .factory
            model.archive.onboardingComplete = true
            model.targets = TargetsModel.from(.factory)
            model.route = .hub
            return (model, .persistNow)
        }
        var model = model
        let (next, cmd) = OnboardingUpdate.update(msg: message, model: model.onboarding)
        model.onboarding = next
        return (model, cmd)
    }

    private static func wish(_ message: WishMsg, model: AppModel) -> (AppModel, CalibrationCmd) {
        if case .returnToHub = message {
            return returnToHub(model)
        }
        if case .promote(let barcode) = message {
            var model = model
            if let specimen = model.archive.specimen(for: barcode) {
                model.scale = ScaleModel.loaded(specimen)
                model.route = .weigh
                return (model, .startScanner)
            }
            return (model, .none)
        }
        if case .deleteConfirmed(let barcode) = message {
            var model = model
            model.archive.wishes.removeAll { $0.barcode == barcode }
            return (model, .persistNow)
        }
        var model = model
        let (next, cmd) = WishUpdate.update(msg: message, model: model.wish)
        model.wish = next
        return (model, cmd)
    }
}
