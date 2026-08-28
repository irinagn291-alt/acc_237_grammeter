import SwiftUI

struct LogView: View {
    @ObservedObject var runtime: WeighRuntime

    var body: some View {
        let model = runtime.model.log
        let rows = runtime.model.archive.eaten(on: model.day)
        VStack(spacing: 0) {
            HStack {
                GaugeBackButton { runtime.send(.log(.returnToHub)) }
                Text("Log")
                    .font(GaugeType.headline)
                    .foregroundStyle(GaugePalette.ink)
                Spacer()
            }
            .padding(.horizontal, GaugeSpace.n(2))
            HStack {
                Button("Previous day") { runtime.send(.log(.shiftDay(-1))) }
                    .frame(minWidth: GaugeSpace.tap, minHeight: GaugeSpace.tap)
                    .accessibilityLabel("Previous day")
                Spacer()
                Text(model.day.date(), style: .date)
                    .font(GaugeType.headline)
                    .foregroundStyle(GaugePalette.ink)
                Spacer()
                Button("Next day") { runtime.send(.log(.shiftDay(1))) }
                    .frame(minWidth: GaugeSpace.tap, minHeight: GaugeSpace.tap)
                    .accessibilityLabel("Next day")
            }
            .padding(GaugeSpace.n(2))
            if rows.isEmpty {
                EmptyGaugeState(
                    image: "gmt_EmptyLog",
                    title: "Pan is empty",
                    detail: "Nothing has been committed for this day.",
                    actionTitle: "Back to hub",
                    action: { runtime.send(.log(.returnToHub)) }
                )
                Spacer()
            } else {
                List {
                    ForEach(WeighSlot.allCases) { slot in
                        let group = rows.filter { $0.slot == slot }
                        if !group.isEmpty {
                            Section {
                                ForEach(group) { record in
                                    logRow(record)
                                        .listRowBackground(
                                            record.id == runtime.model.hub.lastAddedID
                                                ? GaugePalette.accent.opacity(0.14)
                                                : GaugePalette.surface
                                        )
                                }
                            } header: {
                                HStack {
                                    Text(slot.label)
                                    Spacer()
                                    Text(GaugeFormat.energy(DayTotals.energy(records: group, archive: runtime.model.archive)))
                                }
                                .font(GaugeType.footnote)
                                .foregroundStyle(GaugePalette.muted)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(GaugePalette.background.ignoresSafeArea())
        .confirmationDialog(
            "Delete this weigh-in?",
            isPresented: Binding(
                get: { model.pendingDelete != nil },
                set: { if !$0 { runtime.send(.log(.cancelDelete)) } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = model.pendingDelete {
                    runtime.send(.log(.deleteConfirmed(id)))
                }
            }
            Button("Cancel", role: .cancel) { runtime.send(.log(.cancelDelete)) }
        }
    }

    private func logRow(_ record: WeighRecord) -> some View {
        let specimen = runtime.model.archive.specimen(for: record.barcode)
        return HStack {
            SpecimenThumb(specimen: specimen)
            VStack(alignment: .leading) {
                Text(specimen?.name ?? record.barcode)
                    .font(GaugeType.body)
                    .foregroundStyle(GaugePalette.ink)
                    .lineLimit(1)
                Text("\(GaugeFormat.mass(record.grams)) g · \(GaugeFormat.energy(PortionMath.energy(specimen: specimen, grams: record.grams) ?? 0)) kcal")
                    .font(GaugeType.caption)
                    .foregroundStyle(GaugePalette.muted)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                runtime.send(.log(.askDelete(record.id)))
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(GaugePalette.ink)
                    .frame(width: GaugeSpace.tap, height: GaugeSpace.tap)
            }
            .accessibilityLabel("Delete weigh-in")
        }
        .frame(minHeight: GaugeSpace.tap)
    }
}
