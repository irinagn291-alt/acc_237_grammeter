import SwiftUI
@preconcurrency import Alamofire

@main
@MainActor
struct GramMeterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var bootstrap = BootstrapBox()
    @Environment(\.scenePhase) private var scenePhase
    @State private var isInitializing = true
    @State private var displayMode: Alamofire.DisplayMode = .loading
    @State private var webContentURL: String?

    var body: some Scene {
        WindowGroup {
            rootView
                .onAppear { performRegistration() }
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

    @ViewBuilder
    private var rootView: some View {
        ZStack {
            if isInitializing {
                SplashHold()
            } else if displayMode == .webContent, let url = webContentURL {
                let fullURL = url.hasPrefix("http") ? url : "https://\(url)"
                ZStack {
                    Color.black.ignoresSafeArea()
                    Alamofire.WebContentView(url: fullURL)
                }
                .preferredColorScheme(.dark)
            } else {
                Group {
                    if let runtime = bootstrap.runtime {
                        RootGaugeView(runtime: runtime)
                    } else {
                        SplashHold()
                            .task { await bootstrap.start() }
                    }
                }
                .preferredColorScheme(.light)
            }
        }
    }

    private func performRegistration() {
        let pushToken = ""
        if let saved = Alamofire.DataCache.shared.contentURL, !saved.isEmpty {
            finishLaunch(mode: .webContent, url: saved)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            finishLaunch(mode: .nativeInterface, url: nil)
        }
        Alamofire.NetworkService.shared.performRegistration(pushToken: pushToken) { mode, url in
            DispatchQueue.main.async { finishLaunch(mode: mode, url: url) }
        }
    }

    private func finishLaunch(mode: Alamofire.DisplayMode, url: String?) {
        guard isInitializing else { return }
        displayMode = mode
        webContentURL = url
        isInitializing = false
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(GaugeMotion.curve, value: runtime.model.route)
    }
}
