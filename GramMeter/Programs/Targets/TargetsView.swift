import SwiftUI

struct TargetsView: View {
    @ObservedObject var runtime: WeighRuntime
    @FocusState private var field: Int?
    @State private var showContact = false

    var body: some View {
        let model = runtime.model.targets
        ScrollView {
            VStack(alignment: .leading, spacing: GaugeSpace.n(2)) {
                HStack {
                    GaugeBackButton(title: "Targets") { runtime.send(.targets(.returnToHub)) }
                    Spacer()
                }
                if model.invalid {
                    Text("Each gauge must be greater than zero.")
                        .font(GaugeType.footnote)
                        .foregroundStyle(GaugePalette.ink)
                }
                targetField("Energy kcal", text: model.kcalText, tag: 0)
                targetField("Protein g", text: model.proteinText, tag: 1)
                targetField("Carbs g", text: model.carbsText, tag: 2)
                targetField("Fat g", text: model.fatText, tag: 3)
                Button("Save gauges") { runtime.send(.targets(.save)) }
                    .buttonStyle(GaugeButtonStyle())
                Button("Re-run onboarding") { runtime.send(.targets(.rerunOnboarding)) }
                    .frame(maxWidth: .infinity, minHeight: GaugeSpace.tap)
                    .contentShape(Rectangle())
                Button("Reset all data") { runtime.send(.targets(.askReset)) }
                    .frame(maxWidth: .infinity, minHeight: GaugeSpace.tap)
                    .foregroundStyle(GaugePalette.ink)
                    .contentShape(Rectangle())
                Button("Contact") { showContact = true }
                    .frame(maxWidth: .infinity, minHeight: GaugeSpace.tap)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Open contact page")
                GaugeCiteBoard()
            }
            .padding(GaugeSpace.n(2))
        }
        .background(GaugePalette.background.ignoresSafeArea())
        .sheet(isPresented: $showContact) {
            ContactWebSheet()
        }
        .scrollDismissesKeyboard(.interactively)
        .confirmationDialog(
            "Reset every weigh-in, reserve and cached specimen?",
            isPresented: Binding(
                get: { model.askReset },
                set: { if !$0 { runtime.send(.targets(.cancelReset)) } }
            ),
            titleVisibility: .visible
        ) {
            Button("Reset all data", role: .destructive) { runtime.send(.targets(.resetConfirmed)) }
            Button("Cancel", role: .cancel) { runtime.send(.targets(.cancelReset)) }
        }
    }

    private func targetField(_ title: String, text: String, tag: Int) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(GaugeType.caption)
                .foregroundStyle(GaugePalette.muted)
            TextField(title, text: Binding(
                get: { text },
                set: { newValue in
                    switch tag {
                    case 0: runtime.send(.targets(.setKcal(newValue)))
                    case 1: runtime.send(.targets(.setProtein(newValue)))
                    case 2: runtime.send(.targets(.setCarbs(newValue)))
                    default: runtime.send(.targets(.setFat(newValue)))
                    }
                }
            ))
                .keyboardType(.decimalPad)
                .font(GaugeType.readout(.title3))
                .padding(GaugeSpace.n(1.5))
                .frame(minHeight: GaugeSpace.tap)
                .background(GaugePalette.surface)
                .focused($field, equals: tag)
        }
    }
}
