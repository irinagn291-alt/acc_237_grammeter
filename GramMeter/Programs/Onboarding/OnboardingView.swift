import SwiftUI

struct OnboardingView: View {
    @ObservedObject var runtime: WeighRuntime
    @FocusState private var field: Int?

    var body: some View {
        let model = runtime.model.onboarding
        VStack(spacing: GaugeSpace.n(2)) {
            TabView(selection: Binding(
                get: { model.page },
                set: { next in
                    if next > model.page { runtime.send(.onboarding(.next)) }
                    else if next < model.page { runtime.send(.onboarding(.back)) }
                }
            )) {
                page(
                    image: "gmt_Onboarding1",
                    title: "Weigh it properly",
                    detail: "GramMeter is a personal food log. Tare the vessel, then read net grams.",
                    tag: 0
                )
                page(
                    image: "gmt_Onboarding2",
                    title: "Catalog and live scan",
                    detail: "Search the catalog or drop a barcode straight onto the scale readout.",
                    tag: 1
                )
                page(
                    image: "gmt_Onboarding3",
                    title: "Set the daily gauges",
                    detail: "Energy, protein, carbs and fat. Skip writes a factory set cited on the next page.",
                    tag: 2
                )
                targetPage(model)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            HStack {
                if model.page > 0 {
                    Button("Back") { runtime.send(.onboarding(.back)) }
                        .frame(minHeight: GaugeSpace.tap)
                        .contentShape(Rectangle())
                }
                Spacer()
                Button("Skip") { runtime.send(.onboarding(.skip)) }
                    .frame(minHeight: GaugeSpace.tap)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Skip and use default targets")
            }
            .padding(.horizontal, GaugeSpace.n(2))
            if model.page < 3 {
                Button("Continue") { runtime.send(.onboarding(.next)) }
                    .buttonStyle(GaugeButtonStyle())
                    .padding(.horizontal, GaugeSpace.n(2))
            } else {
                Button("Write gauges") { runtime.send(.onboarding(.finish)) }
                    .buttonStyle(GaugeButtonStyle())
                    .padding(.horizontal, GaugeSpace.n(2))
            }
        }
        .padding(.bottom, GaugeSpace.n(2))
        .background(GaugePalette.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
    }

    private func page(image: String, title: String, detail: String, tag: Int) -> some View {
        VStack(spacing: GaugeSpace.n(2)) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 280)
                .accessibilityHidden(true)
            Text(title)
                .font(GaugeType.headline)
                .foregroundStyle(GaugePalette.ink)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(GaugeType.body)
                .foregroundStyle(GaugePalette.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, GaugeSpace.n(2))
        }
        .tag(tag)
    }

    private func targetPage(_ model: OnboardingModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GaugeSpace.n(1.5)) {
                Image("gmt_TwistHero")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 160)
                    .accessibilityHidden(true)
                Text("Precision first")
                    .font(GaugeType.headline)
                Text("Tare, then gross. Convert g, oz or ml. Save slice, cup and tablespoon presets.")
                    .font(GaugeType.body)
                    .foregroundStyle(GaugePalette.muted)
                field("Energy kcal", text: model.kcalText, tag: 0)
                field("Protein g", text: model.proteinText, tag: 1)
                field("Carbs g", text: model.carbsText, tag: 2)
                field("Fat g", text: model.fatText, tag: 3)
                GaugeCiteBoard()
            }
            .padding(GaugeSpace.n(2))
        }
        .tag(3)
    }

    private func field(_ title: String, text: String, tag: Int) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(GaugeType.caption)
                .foregroundStyle(GaugePalette.muted)
            TextField(title, text: Binding(
                get: { text },
                set: { newValue in
                    switch tag {
                    case 0: runtime.send(.onboarding(.setKcal(newValue)))
                    case 1: runtime.send(.onboarding(.setProtein(newValue)))
                    case 2: runtime.send(.onboarding(.setCarbs(newValue)))
                    default: runtime.send(.onboarding(.setFat(newValue)))
                    }
                }
            ))
                .keyboardType(.decimalPad)
                .padding(GaugeSpace.n(1.5))
                .frame(minHeight: GaugeSpace.tap)
                .background(GaugePalette.surface)
                .focused($field, equals: tag)
        }
    }
}
