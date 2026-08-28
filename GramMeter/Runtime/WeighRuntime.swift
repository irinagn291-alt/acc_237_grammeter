import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Executes CalibrationCmd and feeds results back as Msg. Scene-scoped, never a singleton.
@MainActor
final class WeighRuntime: ObservableObject {
    @Published private(set) var model: AppModel

    private let disk: LedgerDisk
    private let client: CatalogClient
    private var persistTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var resolveTask: Task<Void, Never>?
    private let scanner: LiveScanSession

    var scanSession: LiveScanSession { scanner }

    init(archive: ScaleArchive, notice: String?, today: DayKey, disk: LedgerDisk = LedgerDisk()) {
        self.disk = disk
        self.client = CatalogClient()
        self.scanner = LiveScanSession()
        self.model = AppModel.launch(archive: archive, today: today, notice: notice)
        scanner.onCode = { [weak self] raw in
            self?.send(.scale(.decoded(raw)))
        }
    }

    static func bootstrap() async -> WeighRuntime {
        let disk = LedgerDisk()
        let (archive, notice) = await disk.load()
        let runtime = WeighRuntime(archive: archive, notice: notice, today: DayKey(from: Date()), disk: disk)
        #if targetEnvironment(simulator)
        if !UserDefaults.standard.bool(forKey: GaugeLinks.demoFlag) {
            runtime.send(.hub(.seedDemo(day: DayKey(from: Date()))))
        }
        #endif
        return runtime
    }

    func send(_ msg: AppMsg) {
        let (next, cmd) = AppUpdate.update(msg: msg, model: model)
        model = next
        perform(cmd)
    }

    func resetAllData() {
        send(.targets(.resetConfirmed))
    }

    func flushNow() {
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            await self?.writeArchive()
        }
    }

    private func perform(_ cmd: CalibrationCmd) {
        switch cmd {
        case .none:
            break
        case .batch(let commands):
            for item in commands { perform(item) }
        case .persist:
            persistTask?.cancel()
            persistTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                await self?.writeArchive()
            }
        case .persistNow:
            flushNow()
        case .search(let query):
            searchTask?.cancel()
            searchTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                self.send(.catalog(.searchDue))
                let spinner = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(150))
                    guard !Task.isCancelled else { return }
                    self?.send(.catalog(.revealSpinner))
                }
                let outcome = await self.client.search(terms: query)
                spinner.cancel()
                guard !Task.isCancelled else { return }
                switch outcome {
                case .value(let remote):
                    let merged = Self.merge(remote: remote, query: query)
                    self.send(.catalog(.finished(merged.hits, usedShelf: merged.usedShelf)))
                case .fault(let fault):
                    self.send(.catalog(.failed(fault)))
                }
            }
        case .resolve(let raw):
            resolveTask?.cancel()
            resolveTask = Task { [weak self] in
                guard let self else { return }
                let spinner = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(150))
                    guard !Task.isCancelled else { return }
                    self?.send(.scale(.revealSpinner))
                }
                if let cached = self.cachedSpecimen(raw) {
                    spinner.cancel()
                    self.send(.scale(.resolved(cached)))
                    return
                }
                let outcome = await self.client.resolve(code: raw)
                spinner.cancel()
                guard !Task.isCancelled else { return }
                switch outcome {
                case .value(let specimen):
                    self.send(.scale(.resolved(specimen)))
                case .fault(let fault):
                    self.send(.scale(.resolveFailed(fault)))
                }
            }
        case .haptic:
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        case .requestCamera:
            scanner.requestAccess { [weak self] permission in
                self?.send(.scale(.permission(permission)))
            }
        case .startScanner:
            scanner.start()
        case .stopScanner:
            scanner.stop()
        case .openSettings:
            #if canImport(UIKit)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            #endif
        case .openContact:
            #if canImport(UIKit)
            UIApplication.shared.open(GaugeLinks.contact)
            #endif
        case .markDemoSeeded:
            UserDefaults.standard.set(true, forKey: GaugeLinks.demoFlag)
        }
    }

    private func cachedSpecimen(_ raw: String) -> MassSpecimen? {
        for code in BarcodeNormalizer.candidates(from: raw) {
            if let hit = model.archive.specimen(for: code) { return hit }
        }
        return nil
    }

    private static func merge(remote: [MassSpecimen], query: String) -> (hits: [MassSpecimen], usedShelf: Bool) {
        let local = DemoShelf.matches(query: query)
        var seen = Set<String>()
        var hits: [MassSpecimen] = []
        for specimen in remote + local where specimen.hasUsableName {
            if seen.insert(specimen.barcode).inserted {
                hits.append(specimen)
            }
        }
        return (hits, remote.isEmpty && !local.isEmpty)
    }

    private func writeArchive() async {
        do {
            try await disk.save(model.archive)
        } catch {
            var next = model
            next.restoreNotice = "The last weigh-in could not be written. The scale still shows what is in memory."
            model = next
        }
    }
}
