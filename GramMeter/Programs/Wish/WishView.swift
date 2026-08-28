import SwiftUI

struct WishView: View {
    @ObservedObject var runtime: WeighRuntime

    var body: some View {
        let wishes = runtime.model.archive.wishes
        VStack(spacing: 0) {
            HStack {
                GaugeBackButton(title: "Reserved") { runtime.send(.wish(.returnToHub)) }
                Spacer()
            }
            .padding(GaugeSpace.n(2))
            if wishes.isEmpty {
                EmptyGaugeState(
                    image: "gmt_EmptyWish",
                    title: "Nothing reserved",
                    detail: "Reserve a specimen from the scale when you intend to buy it.",
                    actionTitle: "Back to hub",
                    action: { runtime.send(.wish(.returnToHub)) }
                )
                Spacer()
            } else {
                List {
                    ForEach(wishes) { wish in
                        let specimen = runtime.model.archive.specimen(for: wish.barcode)
                        HStack {
                            SpecimenThumb(specimen: specimen)
                            VStack(alignment: .leading) {
                                Text(specimen?.name ?? wish.barcode)
                                    .font(GaugeType.body)
                                    .foregroundStyle(GaugePalette.ink)
                                    .lineLimit(1)
                                Text(wish.added, style: .date)
                                    .font(GaugeType.caption)
                                    .foregroundStyle(GaugePalette.muted)
                            }
                            Spacer()
                            Button("Weigh") { runtime.send(.wish(.promote(wish.barcode))) }
                                .buttonStyle(.borderless)
                                .frame(minHeight: GaugeSpace.tap)
                                .contentShape(Rectangle())
                                .accessibilityLabel("Promote to scale")
                            Button {
                                runtime.send(.wish(.askDelete(wish.barcode)))
                            } label: {
                                Image(systemName: "xmark")
                                    .frame(width: GaugeSpace.tap, height: GaugeSpace.tap)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove reserved specimen")
                        }
                        .listRowBackground(GaugePalette.surface)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(GaugePalette.background.ignoresSafeArea())
        .alert("Remove this reserved specimen?", isPresented: Binding(
            get: { runtime.model.wish.pendingDelete != nil },
            set: { if !$0 { runtime.send(.wish(.cancelDelete)) } }
        )) {
            Button("Remove", role: .destructive) {
                if let barcode = runtime.model.wish.pendingDelete {
                    runtime.send(.wish(.deleteConfirmed(barcode)))
                }
            }
            Button("Cancel", role: .cancel) { runtime.send(.wish(.cancelDelete)) }
        }
    }
}
