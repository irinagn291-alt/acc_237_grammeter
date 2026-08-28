import SwiftUI

/// Scale readout using DIN Alternate and Metal color/distortion/layer effects.
struct ReadoutView: View {
    let grams: Double?
    let unit: MassUnit
    var reduceMotion: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 10 : 1.0 / 24.0, paused: reduceMotion)) { context in
            let time = Float(context.date.timeIntervalSinceReferenceDate)
            VStack(spacing: GaugeSpace.n(1)) {
                Text(grams.map(GaugeFormat.mass) ?? "—")
                    .font(GaugeType.readout(.largeTitle))
                    .foregroundStyle(GaugePalette.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .colorEffect(ShaderLibrary.readoutGlow(.float(time), .float(reduceMotion ? 0 : 1)))
                    .accessibilityLabel("Net mass \(grams.map(GaugeFormat.mass) ?? "unknown") \(unit.label)")
                Text(unit.label)
                    .font(GaugeType.headline)
                    .foregroundStyle(GaugePalette.muted)
                needle(time: time)
            }
            .frame(maxWidth: .infinity)
            .padding(GaugeSpace.n(2))
            .background {
                Rectangle()
                    .fill(GaugePalette.surface)
                    .layerEffect(ShaderLibrary.gradientNoise(.float(reduceMotion ? 0 : time)), maxSampleOffset: .zero)
            }
        }
    }

    private func needle(time: Float) -> some View {
        Rectangle()
            .fill(GaugePalette.accent)
            .frame(height: 4)
            .distortionEffect(ShaderLibrary.needleBlur(.float(reduceMotion ? 0 : time)), maxSampleOffset: CGSize(width: 8, height: 0))
            .accessibilityHidden(true)
    }
}

struct SpecimenThumb: View {
    let specimen: MassSpecimen?

    var body: some View {
        Group {
            if let urlString = specimen?.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: 56, height: 56)
        .clipped()
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var fallback: some View {
        if let asset = specimen?.shelfAsset {
            Image(asset).resizable().scaledToFill()
        } else {
            Image("gmt_ProductPlaceholder").resizable().scaledToFill()
        }
    }
}

struct EmptyGaugeState: View {
    let image: String
    let title: String
    let detail: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: GaugeSpace.n(2)) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .accessibilityHidden(true)
            Text(title)
                .font(GaugeType.headline)
                .foregroundStyle(GaugePalette.ink)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(GaugeType.body)
                .foregroundStyle(GaugePalette.muted)
                .multilineTextAlignment(.center)
            Button(actionTitle, action: action)
                .buttonStyle(GaugeButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(GaugeSpace.n(3))
    }
}

struct GaugeButtonStyle: ButtonStyle {
    var destructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GaugeType.headline)
            .foregroundStyle(GaugePalette.surface)
            .frame(minHeight: GaugeSpace.tap)
            .frame(maxWidth: .infinity)
            .background(destructive ? GaugePalette.ink : GaugePalette.accent)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct GaugeBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(GaugeType.headline)
                .foregroundStyle(GaugePalette.ink)
                .frame(width: GaugeSpace.tap, height: GaugeSpace.tap)
        }
        .accessibilityLabel("Back to hub")
    }
}
