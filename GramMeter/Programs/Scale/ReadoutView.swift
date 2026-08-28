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
                    .frame(maxWidth: .infinity)
                    .colorEffect(ShaderLibrary.readoutGlow(.float(time), .float(reduceMotion ? 0 : 1)))
                    .accessibilityLabel("Net mass \(grams.map(GaugeFormat.mass) ?? "unknown") \(unit.label)")
                Text(unit.label)
                    .font(GaugeType.headline)
                    .foregroundStyle(GaugePalette.ink)
                needle(time: time)
            }
            .frame(maxWidth: .infinity, minHeight: 140)
            .padding(GaugeSpace.n(3))
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
                .clipped()
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
        .padding(GaugeSpace.n(3))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct GaugeButtonStyle: ButtonStyle {
    var destructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GaugeType.headline)
            .foregroundStyle(GaugePalette.surface)
            .frame(maxWidth: .infinity, minHeight: GaugeSpace.tap)
            .background(destructive ? GaugePalette.ink : GaugePalette.accent)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct GaugeChipButtonStyle: ButtonStyle {
    var fill: Color = GaugePalette.surface
    var ink: Color = GaugePalette.ink
    var expand: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GaugeType.headline)
            .foregroundStyle(ink)
            .padding(.horizontal, GaugeSpace.n(1.5))
            .frame(minWidth: GaugeSpace.tap, maxWidth: expand ? .infinity : nil, minHeight: GaugeSpace.tap)
            .background(fill)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct GaugeBackButton: View {
    var title: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: GaugeSpace.n(1)) {
                Image(systemName: "chevron.left")
                    .font(GaugeType.headline)
                if !title.isEmpty {
                    Text(title)
                        .font(GaugeType.headline)
                }
            }
            .foregroundStyle(GaugePalette.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minWidth: 88, minHeight: GaugeSpace.tap, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title.isEmpty ? "Back to hub" : "Back to hub, \(title)")
    }
}
