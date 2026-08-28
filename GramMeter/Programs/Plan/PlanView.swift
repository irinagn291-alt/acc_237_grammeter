import SwiftUI

struct PlanView: View {
    @ObservedObject var runtime: WeighRuntime

    var body: some View {
        let model = runtime.model.plan
        let rows = runtime.model.archive.planned(from: model.today.adding(days: 1), through: model.horizonEnd)
        VStack(spacing: 0) {
            HStack {
                GaugeBackButton(title: "Plan") { runtime.send(.plan(.returnToHub)) }
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
            } else {
                List {
                    ForEach(rows) { record in
                        planRow(record)
                            .listRowBackground(GaugePalette.surface)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(GaugePalette.background.ignoresSafeArea())
        .alert("Delete this planned weigh-in?", isPresented: deletePresented) {
            Button("Delete", role: .destructive) {
                if let id = model.pendingDelete {
                    runtime.send(.plan(.deleteConfirmed(id)))
                }
            }
            Button("Cancel", role: .cancel) { runtime.send(.plan(.cancelDelete)) }
        }
    }

    private var deletePresented: Binding<Bool> {
        Binding(
            get: { runtime.model.plan.pendingDelete != nil },
            set: { if !$0 { runtime.send(.plan(.cancelDelete)) } }
        )
    }

    private func planRow(_ record: WeighRecord) -> some View {
        let specimen = runtime.model.archive.specimen(for: record.barcode)
        return VStack(alignment: .leading, spacing: GaugeSpace.n(1)) {
            Button {
                runtime.send(.plan(.open(record.id)))
            } label: {
                HStack {
                    SpecimenThumb(specimen: specimen)
                    VStack(alignment: .leading) {
                        Text(specimen?.name ?? record.barcode)
                            .font(GaugeType.body)
                            .foregroundStyle(GaugePalette.ink)
                            .lineLimit(1)
                        Text("\(record.slot.label) · \(record.day.date(), style: .date)")
                            .font(GaugeType.caption)
                            .foregroundStyle(GaugePalette.muted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: GaugeSpace.tap, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(specimen?.name ?? record.barcode)
            HStack {
                Button("Eat today") { runtime.send(.plan(.eat(record.id))) }
                    .buttonStyle(GaugeChipButtonStyle(expand: true))
                    .accessibilityLabel("Convert to eaten")
                Button("Delete") { runtime.send(.plan(.askDelete(record.id))) }
                    .buttonStyle(GaugeChipButtonStyle(expand: true))
                    .accessibilityLabel("Delete planned weigh-in")
            }
        }
        .padding(.vertical, 4)
    }
}
