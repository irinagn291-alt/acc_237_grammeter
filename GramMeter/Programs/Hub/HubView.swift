import SwiftUI

struct HubView: View {
    @ObservedObject var runtime: WeighRuntime
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let model = runtime.model
        let eaten = model.archive.eaten(on: model.hub.today)
        let energy = DayTotals.energy(records: eaten, archive: model.archive)
        let protein = DayTotals.protein(records: eaten, archive: model.archive)
        let carbs = DayTotals.carbs(records: eaten, archive: model.archive)
        let fat = DayTotals.fat(records: eaten, archive: model.archive)
        ScrollView {
            VStack(alignment: .leading, spacing: GaugeSpace.n(2)) {
                Image("gmt_HeaderDecor")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 88)
                    .clipped()
                    .accessibilityHidden(true)
                Text("Today")
                    .font(GaugeType.headline)
                    .foregroundStyle(GaugePalette.muted)
                energyBlock(energy: energy, target: model.archive.targets.kcal)
                macroRow(protein: protein, carbs: carbs, fat: fat, targets: model.archive.targets)
                GaugeCiteBoard()
                twistCard
                spokeGrid
                slotList(eaten: eaten, archive: model.archive, highlight: model.hub.lastAddedID)
            }
            .padding(GaugeSpace.n(2))
        }
        .background {
            ZStack {
                GaugePalette.background
                Image("gmt_Texture")
                    .resizable(resizingMode: .tile)
                    .opacity(0.12)
                    .accessibilityHidden(true)
            }
            .ignoresSafeArea()
        }
        .alert("Archive note", isPresented: Binding(
            get: { runtime.model.restoreNotice != nil },
            set: { if !$0 { runtime.send(.hub(.dismissNotice)) } }
        )) {
            Button("OK") { runtime.send(.hub(.dismissNotice)) }
        } message: {
            Text(runtime.model.restoreNotice ?? "")
        }
    }

    private func energyBlock(energy: Double, target: Double) -> some View {
        let over = energy > target
        return VStack(alignment: .leading, spacing: GaugeSpace.n(1)) {
            Text(GaugeFormat.energy(energy))
                .font(GaugeType.readout(.largeTitle))
                .foregroundStyle(over ? GaugePalette.ink : GaugePalette.accent)
                .contentTransition(reduceMotion ? .opacity : .numericText())
                .animation(GaugeMotion.fade(reduceMotion: reduceMotion), value: energy)
            Text("of \(GaugeFormat.energy(target)) kcal")
                .font(GaugeType.body)
                .foregroundStyle(GaugePalette.muted)
            GeometryReader { geo in
                let ratio = target <= 0 ? 0 : min(energy / target, 1)
                ZStack(alignment: .leading) {
                    Rectangle().fill(GaugePalette.muted.opacity(0.25))
                    Rectangle().fill(GaugePalette.accent).frame(width: geo.size.width * ratio)
                }
            }
            .frame(height: 8)
            if over {
                Text("Over the energy gauge")
                    .font(GaugeType.footnote)
                    .foregroundStyle(GaugePalette.ink)
            }
        }
        .padding(GaugeSpace.n(2))
        .background(GaugePalette.surface)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Energy \(GaugeFormat.energy(energy)) of \(GaugeFormat.energy(target)) kilocalories")
    }

    private func macroRow(protein: Double?, carbs: Double?, fat: Double?, targets: GaugeTargets) -> some View {
        HStack(spacing: GaugeSpace.n(1)) {
            macroCell(asset: "gmt_MacroProtein", title: "Protein", value: protein, target: targets.proteinGrams)
            macroCell(asset: "gmt_MacroCarbs", title: "Carbs", value: carbs, target: targets.carbsGrams)
            macroCell(asset: "gmt_MacroFat", title: "Fat", value: fat, target: targets.fatGrams)
        }
    }

    private func macroCell(asset: String, title: String, value: Double?, target: Double) -> some View {
        VStack(spacing: GaugeSpace.n(1)) {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            Text(title)
                .font(GaugeType.caption)
                .foregroundStyle(GaugePalette.muted)
            Text("\(GaugeFormat.macro(value)) / \(GaugeFormat.macro(target))")
                .font(GaugeType.footnote)
                .foregroundStyle(GaugePalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: GaugeSpace.tap)
        .padding(GaugeSpace.n(1))
        .background(GaugePalette.surface)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(GaugeFormat.unknownMacro(value)) of \(GaugeFormat.macro(target)) grams")
    }

    private var twistCard: some View {
        Button {
            runtime.send(.hub(.open(.weigh)))
        } label: {
            HStack(spacing: GaugeSpace.n(2)) {
                Image("gmt_TwistHero")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipped()
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: GaugeSpace.n(0.5)) {
                    Text("Precision weigh")
                        .font(GaugeType.headline)
                        .foregroundStyle(GaugePalette.ink)
                    Text("Tare the vessel, then read net grams, ounces or millilitres.")
                        .font(GaugeType.footnote)
                        .foregroundStyle(GaugePalette.muted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(GaugeSpace.n(2))
            .background(GaugePalette.surface)
            .frame(minHeight: GaugeSpace.tap)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Open precision weigh")
    }

    private var spokeGrid: some View {
        let spokes: [(Spoke, String, String)] = [
            (.weigh, "Weigh", "gmt_ControlFace"),
            (.catalog, "Catalog", "gmt_EmptySearch"),
            (.log, "Log", "gmt_EmptyLog"),
            (.plan, "Plan", "gmt_EmptyPlan"),
            (.targets, "Targets", "gmt_Onboarding3"),
            (.wish, "Reserved", "gmt_EmptyWish")
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: GaugeSpace.n(1)) {
            ForEach(spokes, id: \.0) { item in
                Button {
                    runtime.send(.hub(.open(item.0)))
                } label: {
                    VStack(spacing: GaugeSpace.n(1)) {
                        Image(item.2)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipped()
                            .accessibilityHidden(true)
                        Text(item.1)
                            .font(GaugeType.footnote)
                            .foregroundStyle(GaugePalette.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: GaugeSpace.tap)
                    .padding(GaugeSpace.n(1))
                    .background(GaugePalette.surface)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel(item.1)
            }
        }
    }

    private func slotList(eaten: [WeighRecord], archive: ScaleArchive, highlight: UUID?) -> some View {
        VStack(alignment: .leading, spacing: GaugeSpace.n(1)) {
            Text("Stations")
                .font(GaugeType.headline)
                .foregroundStyle(GaugePalette.ink)
            ForEach(WeighSlot.allCases) { slot in
                let rows = eaten.filter { $0.slot == slot }
                Button {
                    runtime.send(.hub(.open(.weigh)))
                } label: {
                    HStack(spacing: GaugeSpace.n(1)) {
                        Image(slot.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading) {
                            Text(slot.label)
                                .font(GaugeType.callout)
                                .foregroundStyle(GaugePalette.ink)
                            Text(rows.isEmpty ? "No mass yet" : "\(rows.count) weigh-in\(rows.count == 1 ? "" : "s")")
                                .font(GaugeType.caption)
                                .foregroundStyle(GaugePalette.muted)
                        }
                        Spacer()
                        Text(GaugeFormat.energy(DayTotals.energy(records: rows, archive: archive)))
                            .font(GaugeType.readout(.title3))
                            .foregroundStyle(GaugePalette.accent)
                    }
                    .padding(GaugeSpace.n(1.5))
                    .background(rows.contains(where: { $0.id == highlight }) ? GaugePalette.accent.opacity(0.12) : GaugePalette.surface)
                    .frame(minHeight: GaugeSpace.tap)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("\(slot.label), \(rows.count) items")
            }
        }
    }
}
