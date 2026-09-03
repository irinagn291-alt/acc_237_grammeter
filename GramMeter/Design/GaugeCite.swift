import Foundation
import SwiftUI

/// Public reference standards for factory gauges and catalog figures.
/// Guideline 1.4.1 needs tappable source links, not a static disclaimer.
enum GaugeCite {
    struct Standard: Identifiable, Equatable, Sendable {
        let id: String
        let title: String
        let detail: String
        let url: URL

        init(title: String, detail: String, address: String) {
            self.id = address
            self.title = title
            self.detail = detail
            // Programmer error: a citation address is a compile-time constant.
            guard let parsed = URL(string: address) else {
                fatalError("Citation address must be a valid URL")
            }
            self.url = parsed
        }
    }

    static let standards: [Standard] = [
        Standard(
            title: "Dietary Guidelines for Americans",
            detail: "Adult energy ranges that inform the factory 2,200 kcal daily gauge. Every gauge is user-editable.",
            address: "https://www.dietaryguidelines.gov"
        ),
        Standard(
            title: "NIH Office of Dietary Supplements — DRI / AMDR",
            detail: "Protein 10–35%, carbohydrate 45–65% and fat 20–35% of energy. Factory 140 g / 250 g / 70 g at 2,200 kcal sit in those bands.",
            address: "https://ods.od.nih.gov/HealthInformation/Dietary_Reference_Intakes.aspx"
        ),
        Standard(
            title: "Open Food Facts",
            detail: "Per-specimen energy and macros on the scale and in the catalog. Public, user-contributed database.",
            address: "https://world.openfoodfacts.org"
        ),
        Standard(
            title: "FDA Nutrition Facts label",
            detail: "How packaged-food energy and macronutrient values are defined on labels.",
            address: "https://www.fda.gov/food/nutrition-facts-label/how-understand-and-use-nutrition-facts-label"
        ),
        Standard(
            title: "WHO fact sheet: Healthy diet",
            detail: "Population guidance on energy balance. GramMeter records weigh-ins; it does not prescribe a diet.",
            address: "https://www.who.int/news-room/fact-sheets/detail/healthy-diet"
        )
    ]

    static var openFoodFacts: Standard {
        standards.first { $0.url.host == "world.openfoodfacts.org" } ?? standards[2]
    }
}

/// Tappable source plate. Shown on Today, Targets and the last onboarding page.
@MainActor
struct GaugeCiteBoard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: GaugeSpace.n(1.5)) {
            Text("Sources")
                .font(GaugeType.headline)
                .foregroundStyle(GaugePalette.ink)
            Text("GramMeter is a personal food log, not medical advice. Factory gauges follow these public references. Edit every number on Targets.")
                .font(GaugeType.footnote)
                .foregroundStyle(GaugePalette.muted)
            ForEach(GaugeCite.standards) { standard in
                Link(destination: standard.url) {
                    HStack(alignment: .top, spacing: GaugeSpace.n(1.5)) {
                        Rectangle()
                            .fill(GaugePalette.accent)
                            .frame(width: 3)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: GaugeSpace.n(0.5)) {
                            Text(standard.title)
                                .font(GaugeType.body)
                                .foregroundStyle(GaugePalette.accent)
                                .multilineTextAlignment(.leading)
                            Text(standard.detail)
                                .font(GaugeType.caption)
                                .foregroundStyle(GaugePalette.muted)
                                .multilineTextAlignment(.leading)
                            Text(standard.url.host ?? standard.url.absoluteString)
                                .font(GaugeType.caption)
                                .foregroundStyle(GaugePalette.ink)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(GaugeSpace.n(1.5))
                    .frame(minHeight: GaugeSpace.tap)
                    .background(GaugePalette.background)
                }
                .accessibilityLabel("\(standard.title). Opens source link.")
            }
        }
        .padding(GaugeSpace.n(2))
        .background(GaugePalette.surface)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sources for daily gauges and catalog figures")
    }
}

/// Compact Open Food Facts credit next to a specimen readout.
@MainActor
struct GaugeCiteMark: View {
    var body: some View {
        Link("Open Food Facts source", destination: GaugeCite.openFoodFacts.url)
            .font(GaugeType.footnote)
            .foregroundStyle(GaugePalette.accent)
            .frame(minHeight: GaugeSpace.tap, alignment: .leading)
            .accessibilityLabel("Open Food Facts source")
    }
}
