import SwiftUI

@main
struct GramMeterApp: App {
    @StateObject private var bootstrap = BootstrapBox()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if let runtime = bootstrap.runtime {
                    RootGaugeView(runtime: runtime)
                } else {
                    SplashHold()
                        .task { await bootstrap.start() }
                }
            }
            .preferredColorScheme(.light)
            .onChange(of: scenePhase) { _, phase in
                if phase == .inactive || phase == .background {
                    bootstrap.runtime?.send(.sceneInactive)
                    bootstrap.runtime?.scanSession.stop()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                bootstrap.runtime?.send(.calendarDayDidChange(DayKey(from: Date())))
            }
        }
    }
}

@MainActor
final class BootstrapBox: ObservableObject {
    @Published var runtime: WeighRuntime?

    func start() async {
        guard runtime == nil else { return }
        runtime = await WeighRuntime.bootstrap()
    }
}

struct SplashHold: View {
    var body: some View {
        ZStack {
            GaugePalette.background.ignoresSafeArea()
            Image("gmt_Splash")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .accessibilityHidden(true)
            Text("GramMeter")
                .font(GaugeType.readout(.title))
                .foregroundStyle(GaugePalette.ink)
        }
    }
}

/// Hub-and-spoke root. A spoke never opens a sibling.
struct RootGaugeView: View {
    @ObservedObject var runtime: WeighRuntime

    var body: some View {
        Group {
            switch runtime.model.route {
            case .onboarding:
                OnboardingView(runtime: runtime)
            case .hub:
                HubView(runtime: runtime)
            case .weigh:
                ScaleView(runtime: runtime)
            case .catalog:
                CatalogView(runtime: runtime)
            case .log:
                LogView(runtime: runtime)
            case .plan:
                PlanView(runtime: runtime)
            case .targets:
                TargetsView(runtime: runtime)
            case .wish:
                WishView(runtime: runtime)
            }
        }
        .animation(GaugeMotion.curve, value: runtime.model.route)
    }
}
