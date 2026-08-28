import AVFoundation
import SwiftUI

struct ScaleView: View {
    @ObservedObject var runtime: WeighRuntime
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var field: Field?

    enum Field: Hashable {
        case grams, tare, gross, density, code
    }

    var body: some View {
        let model = runtime.model.scale
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: GaugeSpace.n(2)) {
                    header
                    scanBlock
                    if model.showSpinner {
                        ProgressView("Resolving specimen")
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    resolveCopy
                    if let specimen = model.specimen {
                        specimenCard(specimen)
                    }
                    ReadoutView(grams: model.resolvedGrams, unit: model.unit, reduceMotion: reduceMotion)
                    unitRow
                    massFields
                    presets
                    Button(model.assignOpen ? "Close assign" : "Assign weigh-in") {
                        send(model.assignOpen ? .closeAssign : .openAssign)
                    }
                    .buttonStyle(GaugeButtonStyle())
                    .disabled(model.specimen == nil || model.commitBlocked)
                    if model.assignOpen {
                        assign
                    }
                }
                .padding(GaugeSpace.n(2))
            }
            .onChange(of: field) { _, newValue in
                if let newValue {
                    withAnimation(GaugeMotion.curve) { proxy.scrollTo(newValue, anchor: .center) }
                }
            }
        }
        .background(GaugePalette.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(TapGesture().onEnded { field = nil })
        .alert("Leave this weigh-in?", isPresented: Binding(
            get: { model.askDiscard },
            set: { if !$0 { send(.stay) } }
        )) {
            Button("Stay", role: .cancel) { send(.stay) }
            Button("Discard", role: .destructive) { send(.discardAndLeave) }
        } message: {
            Text("Entered mass will be lost.")
        }
        .onAppear {
            if !runtime.scanSession.hasDevice {
                send(.permission(.missingDevice))
            } else if model.permission == .unknown {
                send(.permission(.unknown))
            }
            runtime.scanSession.start()
        }
        .onDisappear {
            runtime.scanSession.stop()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                runtime.scanSession.stop()
            } else {
                runtime.scanSession.start()
            }
        }
    }

    private var header: some View {
        HStack {
            GaugeBackButton { send(.returnToHub) }
            Text("Weigh")
                .font(GaugeType.headline)
                .foregroundStyle(GaugePalette.ink)
            Spacer()
        }
    }

    private var scanBlock: some View {
        let model = runtime.model.scale
        return VStack(alignment: .leading, spacing: GaugeSpace.n(1)) {
            ZStack {
                if runtime.scanSession.hasDevice && model.permission == .allowed {
                    ScanPreviewView(session: runtime.scanSession.previewSession())
                        .frame(height: 220)
                        .clipped()
                } else {
                    Image("gmt_CardBackdrop")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipped()
                        .accessibilityHidden(true)
                }
                Image("gmt_ScanOverlay")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            permissionCopy
            TextField("Manual barcode", text: Binding(
                get: { model.manualCode },
                set: { send(.setManual($0)) }
            ))
            .keyboardType(.numbersAndPunctuation)
            .font(GaugeType.body)
            .padding(GaugeSpace.n(1.5))
            .frame(minHeight: GaugeSpace.tap)
            .background(GaugePalette.surface)
            .focused($field, equals: .code)
            .id(Field.code)
            Button("Resolve code") { send(.resolveManual) }
                .buttonStyle(GaugeButtonStyle())
                .disabled(model.commitBlocked)
            if !runtime.scanSession.hasDevice {
                sampleChips
            }
        }
    }

    @ViewBuilder
    private var permissionCopy: some View {
        let model = runtime.model.scale
        if !runtime.scanSession.hasDevice {
            Text("No capture device. Use a sample chip or type a code.")
                .font(GaugeType.footnote)
                .foregroundStyle(GaugePalette.muted)
        } else if model.permission == .denied {
            VStack(alignment: .leading, spacing: GaugeSpace.n(1)) {
                Text("Camera access is off. The scale cannot read a live code.")
                    .font(GaugeType.body)
                    .foregroundStyle(GaugePalette.ink)
                Button("Open Settings") { send(.openSettings) }
                    .frame(minHeight: GaugeSpace.tap)
            }
        } else if model.permission == .restricted {
            VStack(alignment: .leading, spacing: GaugeSpace.n(1)) {
                Text("Camera is restricted. Parental controls are blocking the scale.")
                    .font(GaugeType.body)
                    .foregroundStyle(GaugePalette.ink)
                Button("Open Settings") { send(.openSettings) }
                    .frame(minHeight: GaugeSpace.tap)
            }
        }
    }

    private var sampleChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(DemoShelf.specimens) { specimen in
                    Button(specimen.name) {
                        send(.setManual(specimen.barcode))
                        send(.resolveManual)
                    }
                    .font(GaugeType.footnote)
                    .foregroundStyle(GaugePalette.ink)
                    .padding(.horizontal, GaugeSpace.n(1.5))
                    .frame(minHeight: GaugeSpace.tap)
                    .background(GaugePalette.surface)
                    .accessibilityLabel("Sample \(specimen.name)")
                }
            }
        }
    }

    @ViewBuilder
    private var resolveCopy: some View {
        switch runtime.model.scale.resolveState {
        case .idle:
            Text("Point the reticle at a barcode, or enter one.")
                .font(GaugeType.body)
                .foregroundStyle(GaugePalette.muted)
        case .loading, .ready:
            EmptyView()
        case .missingEnergy:
            Text("This specimen has no energy figure. Missing macros stay unknown.")
                .font(GaugeType.body)
                .foregroundStyle(GaugePalette.ink)
        case .notFound:
            Text("No specimen matched that code. Try another candidate or a shelf sample.")
                .font(GaugeType.body)
                .foregroundStyle(GaugePalette.ink)
        case .offline:
            VStack(alignment: .leading) {
                Text("The catalog is out of reach and this code is not on the shelf.")
                    .font(GaugeType.body)
                    .foregroundStyle(GaugePalette.ink)
                Button("Retry") { send(.resolveManual) }
                    .frame(minHeight: GaugeSpace.tap)
            }
        case .malformed:
            VStack(alignment: .leading) {
                Text("The catalog answer could not be read.")
                    .font(GaugeType.body)
                    .foregroundStyle(GaugePalette.ink)
                Button("Retry") { send(.resolveManual) }
                    .frame(minHeight: GaugeSpace.tap)
            }
        }
    }

    private func specimenCard(_ specimen: MassSpecimen) -> some View {
        let wished = runtime.model.archive.isWished(specimen.barcode)
        return HStack(alignment: .top, spacing: GaugeSpace.n(2)) {
            SpecimenThumb(specimen: specimen)
            VStack(alignment: .leading, spacing: GaugeSpace.n(0.5)) {
                Text(specimen.name)
                    .font(GaugeType.headline)
                    .foregroundStyle(GaugePalette.ink)
                    .lineLimit(2)
                Text(specimen.brand.isEmpty ? "Unbranded" : specimen.brand)
                    .font(GaugeType.footnote)
                    .foregroundStyle(GaugePalette.muted)
                    .lineLimit(1)
                Text("\(GaugeFormat.unknownMacro(specimen.kcalPer100g)) kcal / 100 g")
                    .font(GaugeType.callout)
                    .foregroundStyle(GaugePalette.ink)
                HStack {
                    Text("P \(GaugeFormat.macro(specimen.proteinPer100g))")
                    Text("C \(GaugeFormat.macro(specimen.carbsPer100g))")
                    Text("F \(GaugeFormat.macro(specimen.fatPer100g))")
                }
                .font(GaugeType.caption)
                .foregroundStyle(GaugePalette.ink)
                Button(wished ? "Already reserved" : "Reserve") {
                    send(.addWish(Date()))
                }
                .disabled(wished)
                .frame(minHeight: GaugeSpace.tap)
                .accessibilityLabel(wished ? "Already reserved" : "Add to reserved list")
            }
            Spacer(minLength: 0)
        }
        .padding(GaugeSpace.n(2))
        .background {
            Image("gmt_CardBackdrop")
                .resizable()
                .scaledToFill()
                .opacity(0.25)
                .accessibilityHidden(true)
        }
        .background(GaugePalette.surface)
    }

    private var unitRow: some View {
        HStack {
            ForEach(MassUnit.allCases) { unit in
                Button(unit.label) { send(.setUnit(unit)) }
                    .font(GaugeType.headline)
                    .foregroundStyle(runtime.model.scale.unit == unit ? GaugePalette.surface : GaugePalette.ink)
                    .frame(maxWidth: .infinity, minHeight: GaugeSpace.tap)
                    .background(runtime.model.scale.unit == unit ? GaugePalette.accent : GaugePalette.surface)
                    .accessibilityLabel("Unit \(unit.label)")
            }
        }
    }

    private var massFields: some View {
        let model = runtime.model.scale
        return VStack(alignment: .leading, spacing: GaugeSpace.n(1)) {
            if model.gramsRejected {
                Text("Mass must be greater than zero and under 20 000 g.")
                    .font(GaugeType.footnote)
                    .foregroundStyle(GaugePalette.ink)
            }
            labeledField("Portion", text: model.gramsText, field: .grams)
            labeledField("Tare (vessel)", text: model.tareText, field: .tare)
            labeledField("Gross", text: model.grossText, field: .gross)
            if model.unit == .millilitre {
                labeledField("Density g/ml", text: model.densityText, field: .density)
            }
            Text("Net uses tare then gross when both are set. Otherwise the portion field is the charge.")
                .font(GaugeType.footnote)
                .foregroundStyle(GaugePalette.muted)
        }
    }

    private func labeledField(_ title: String, text: String, field: Field) -> some View {
        VStack(alignment: .leading, spacing: GaugeSpace.n(0.5)) {
            Text(title)
                .font(GaugeType.caption)
                .foregroundStyle(GaugePalette.muted)
            TextField(title, text: Binding(
                get: { text },
                set: { newValue in
                    switch field {
                    case .grams: send(.setGrams(newValue))
                    case .tare: send(.setTare(newValue))
                    case .gross: send(.setGross(newValue))
                    case .density: send(.setDensity(newValue))
                    case .code: send(.setManual(newValue))
                    }
                }
            ))
                .keyboardType(.decimalPad)
                .font(GaugeType.readout(.title3))
                .padding(GaugeSpace.n(1.5))
                .frame(minHeight: GaugeSpace.tap)
                .background(GaugePalette.surface)
                .focused($field, equals: field)
                .id(field)
        }
    }

    private var presets: some View {
        let model = runtime.model.scale
        let stored = model.specimen.map { runtime.model.archive.presets(for: $0.barcode) } ?? []
        return VStack(alignment: .leading, spacing: GaugeSpace.n(1)) {
            Text("Portion presets")
                .font(GaugeType.headline)
                .foregroundStyle(GaugePalette.ink)
            HStack {
                ForEach(PortionKind.allCases) { kind in
                    let grams = stored.first(where: { $0.kind == kind })?.grams
                    Button(kind.label) {
                        if let grams { send(.applyPreset(grams)) }
                    }
                    .disabled(grams == nil)
                    .font(GaugeType.footnote)
                    .foregroundStyle(GaugePalette.ink)
                    .frame(maxWidth: .infinity, minHeight: GaugeSpace.tap)
                    .background(GaugePalette.surface)
                    .accessibilityLabel("\(kind.label) preset")
                }
            }
            if let grams = model.resolvedGrams, model.specimen != nil {
                HStack {
                    ForEach(PortionKind.allCases) { kind in
                        Button("Save \(kind.label)") {
                            send(.savePreset(kind, grams))
                        }
                        .font(GaugeType.caption)
                        .frame(maxWidth: .infinity, minHeight: GaugeSpace.tap)
                    }
                }
            }
        }
    }

    private var assign: some View {
        let model = runtime.model.scale
        return VStack(alignment: .leading, spacing: GaugeSpace.n(1)) {
            Text("Station")
                .font(GaugeType.headline)
            ForEach(WeighSlot.allCases) { slot in
                Button {
                    send(.setSlot(slot))
                } label: {
                    HStack {
                        Image(slot.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .accessibilityHidden(true)
                        Text(slot.canPlan || model.eatenToday ? slot.label : "\(slot.label) · remaps to Weigh-In Three")
                            .font(GaugeType.body)
                            .foregroundStyle(GaugePalette.ink)
                        Spacer()
                        if model.slot == (model.eatenToday ? slot : slot.remappedForPlanning()) {
                            Image("gmt_SuccessMark")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(GaugeSpace.n(1))
                    .frame(minHeight: GaugeSpace.tap)
                    .background(GaugePalette.surface)
                }
                .disabled(!slot.canPlan && !model.eatenToday)
                .accessibilityLabel(slot.label)
                .accessibilityHint(slot.canPlan || model.eatenToday ? "" : "Unavailable when planning ahead")
            }
            Toggle("Eaten today", isOn: Binding(
                get: { model.eatenToday },
                set: { send(.setEaten($0)) }
            ))
            .frame(minHeight: GaugeSpace.tap)
            if !model.eatenToday {
                let tomorrow = DayKey(from: Date()).adding(days: 1).date()
                DatePicker(
                    "Future day",
                    selection: Binding(
                        get: { (model.futureDay ?? DayKey(from: Date()).adding(days: 1)).date() },
                        set: { send(.setFuture(DayKey(from: $0))) }
                    ),
                    in: tomorrow...,
                    displayedComponents: .date
                )
                .frame(minHeight: GaugeSpace.tap)
            }
            Button("Commit weigh-in") {
                send(.commit(now: Date(), id: UUID()))
            }
            .buttonStyle(GaugeButtonStyle())
            .disabled(model.commitBlocked || model.specimen == nil)
        }
    }

    private func send(_ msg: ScaleMsg) {
        runtime.send(.scale(msg))
    }
}
