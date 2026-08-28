import SwiftUI

struct CatalogView: View {
    @ObservedObject var runtime: WeighRuntime
    @FocusState private var searchFocused: Bool

    var body: some View {
        let model = runtime.model.catalog
        VStack(spacing: 0) {
            HStack {
                GaugeBackButton { runtime.send(.catalog(.returnToHub)) }
                Text("Catalog")
                    .font(GaugeType.headline)
                    .foregroundStyle(GaugePalette.ink)
                Spacer()
            }
            .padding(.horizontal, GaugeSpace.n(2))
            TextField("Search the catalog", text: Binding(
                get: { model.query },
                set: { runtime.send(.catalog(.setQuery($0))) }
            ))
            .font(GaugeType.body)
            .padding(GaugeSpace.n(1.5))
            .frame(minHeight: GaugeSpace.tap)
            .background(GaugePalette.surface)
            .padding(GaugeSpace.n(2))
            .focused($searchFocused)
            content
        }
        .background(GaugePalette.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private var content: some View {
        let model = runtime.model.catalog
        if model.showSpinner {
            ProgressView("Searching")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 80)
        } else {
            switch model.phase {
            case .idle:
                EmptyGaugeState(
                    image: "gmt_EmptySearch",
                    title: "Weigh by name",
                    detail: "Type a product. Shelf stock fills in if the network is quiet.",
                    actionTitle: "Back to hub",
                    action: { runtime.send(.catalog(.returnToHub)) }
                )
            case .typing, .loading:
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            case .results:
                List {
                    if model.usedShelf {
                        Text("Showing shelf matches")
                            .font(GaugeType.footnote)
                            .foregroundStyle(GaugePalette.muted)
                            .listRowBackground(GaugePalette.background)
                    }
                    ForEach(Array(model.hits.enumerated()), id: \.element.barcode) { index, specimen in
                        Button {
                            runtime.send(.catalog(.picked(specimen)))
                        } label: {
                            HStack(spacing: GaugeSpace.n(1.5)) {
                                SpecimenThumb(specimen: specimen)
                                VStack(alignment: .leading, spacing: GaugeSpace.n(0.5)) {
                                    Text(specimen.name)
                                        .font(GaugeType.body)
                                        .foregroundStyle(GaugePalette.ink)
                                        .lineLimit(1)
                                    Text(specimen.brand)
                                        .font(GaugeType.caption)
                                        .foregroundStyle(GaugePalette.muted)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: GaugeSpace.n(1))
                                Text("\(GaugeFormat.unknownMacro(specimen.kcalPer100g))")
                                    .font(GaugeType.readout(.title3))
                                    .foregroundStyle(GaugePalette.accent)
                                    .lineLimit(1)
                            }
                            .frame(minHeight: GaugeSpace.tap)
                        }
                        .listRowBackground(GaugePalette.surface)
                        .opacity(1)
                        .animation(GaugeMotion.curve.delay(Double(min(index, 8)) * 0.04), value: model.hits.count)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            case .empty:
                EmptyGaugeState(
                    image: "gmt_EmptySearch",
                    title: "Nothing on the scale",
                    detail: "The catalog and the local shelf both came back empty.",
                    actionTitle: "Clear the query",
                    action: { runtime.send(.catalog(.setQuery(""))) }
                )
            case .transport:
                VStack(spacing: GaugeSpace.n(2)) {
                    EmptyGaugeState(
                        image: "gmt_EmptySearch",
                        title: "Catalog is out of reach",
                        detail: "The search did not complete. Retry, or fall back to a typed code on the scale.",
                        actionTitle: "Retry",
                        action: { runtime.send(.catalog(.retry)) }
                    )
                }
            }
        }
    }
}
