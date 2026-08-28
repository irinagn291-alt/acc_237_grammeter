import SwiftUI

struct PlanView: View {
    @ObservedObject var runtime: WeighRuntime

    var body: some View {
        let model = runtime.model.plan
        let rows = runtime.model.archive.planned(from: model.today.adding(days: 1), through: model.horizonEnd)
        VStack(spacing: 0) {
            HStack {
                GaugeBackButton { runtime.send(.plan(.returnToHub)) }
                Text("Plan")
                    .font(GaugeType.headline)
                    .foregroundStyle(GaugePalette.ink)
                Spacer()
            }
            .padding(GaugeSpace.n(2))
            Text("Next 14 days")
                .font(GaugeType.footnote)
                .foregroundStyle(GaugePalette.muted)
            if rows.isEmpty {
                EmptyGaugeState(
                    image: "gmt_EmptyPlan",
                    title: "Horizon is clear",
                    detail: "Nothing is staged on the 14-day horizon.",
                    actionTitle: "Back to hub",
                    action: { runtime.send(.plan(.returnToHub)) }
                )
                Spacer()
            } else {
                List {
                    ForEach(rows) { record in
                        HStack {
                            SpecimenThumb(specimen: runtime.model.archive.specimen(for: record.barcode))
                            VStack(alignment: .leading) {
                                Text(runtime.model.archive.specimen(for: record.barcode)?.name ?? record.barcode)
                                    .font(GaugeType.body)
                                    .foregroundStyle(GaugePalette.ink)
                                    .lineLimit(1)
                                Text("\(record.slot.label) · \(record.day.date(), style: .date)")
                                    .font(GaugeType.caption)
                                    .foregroundStyle(GaugePalette.muted)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button("Eat") { runtime.send(.plan(.eat(record.id))) }
                                .frame(minHeight: GaugeSpace.tap)
                                .accessibilityLabel("Convert to eaten")
                            Button {
                                runtime.send(.plan(.askDelete(record.id)))
                            } label: {
                                Image(systemName: "xmark")
                                    .frame(width: GaugeSpace.tap, height: GaugeSpace.tap)
                            }
                            .accessibilityLabel("Delete planned weigh-in")
                        }
                        .listRowBackground(GaugePalette.surface)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(GaugePalette.background.ignoresSafeArea())
        .confirmationDialog(
            "Delete this planned weigh-in?",
            isPresented: Binding(
                get: { model.pendingDelete != nil },
                set: { if !$0 { runtime.send(.plan(.cancelDelete)) } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let id = model.pendingDelete {
                    runtime.send(.plan(.deleteConfirmed(id)))
                }
            }
            Button("Cancel", role: .cancel) { runtime.send(.plan(.cancelDelete)) }
        }
    }
}
