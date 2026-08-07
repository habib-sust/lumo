//
//  LumoApp.swift
//  Lumo
//

import LumoCore
import LumoShieldKit
import SwiftUI

@main
struct LumoApp: App {

    @State private var authorization = AuthorizationService()
    @State private var selection = SelectionService()
    @AppStorage("lumo.hasCompletedSetup") private var hasCompletedSetup = false

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Layer 4: synchronous reconcile before anything else
    //
    // Shield state is owned by four processes (this app, the DeviceActivityMonitor
    // extension, and the two shield extensions). Whenever this app becomes active it
    // must drive every ManagedSettingsStore back to the state the persisted session
    // implies — BEFORE any UI renders and before the ModelContainer is opened.
    //
    // This must stay synchronous. An `await` here is a suspension point the user can
    // exploit by backgrounding mid-launch, which leaves shields half-applied. There is
    // a merge-blocking CI grep for `async` inside Packages/ for exactly this reason.
    init() {
        // startUp() migrates the schema if needed and then reconciles, both inside the same
        // cross-process lock and in that order — the reconciler must never see a half-converted
        // payload. Only the app may migrate; the extensions read the version and refuse to write
        // on a mismatch.
        // Before startUp(), so a reset lands on a clean slate and seeded state is migrated
        // and reconciled like any other.
        UITestSupport.apply()

        LumoStack.startUp()

        #if DEBUG
        // Printed to stdout, not os_log, specifically so `devicectl --console` can capture it.
        // Family Controls cannot run in the Simulator, so this is the only way to read real
        // on-device state from a development machine.
        print(DebugSnapshot.capture().report)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedSetup || UITestSupport.shouldSkipOnboarding {
                    HomePlaceholder()
                } else {
                    OnboardingFlow { hasCompletedSetup = true }
                }
            }
            .environment(authorization)
            .environment(selection)
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                // Authorization can be revoked in Settings without Lumo running, which unshields
                // everything at once — so it is re-read on every activation rather than trusted
                // from launch. Windows can also expire while the app is suspended.
                LumoStack.reconcileNow(.app)
                authorization.refresh()
            }
        }
    }
}

/// Stands in for the hearth until Phase 4 (T-082).
private struct HomePlaceholder: View {
    @Environment(AuthorizationService.self) private var authorization
    @State private var isShowingSettings = false

    var body: some View {
        ZStack {
            Color.lumoInk.ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.lumoEmber)
                Text("Lumo")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Light comes first.")
                    .font(.subheadline)
                    .foregroundStyle(Color.lumoHaze)

                if let guidance = authorization.guidance {
                    // Surfaced on the home screen too, not only during setup: if access is revoked
                    // later, every locked app silently reopens, and the user deserves to know why
                    // rather than assume Lumo is broken.
                    Text(guidance.title)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.lumoEmber)
                        .padding(.top, 8)
                }

                // Reachable from the first screen, not buried. The escape hatch is worthless if
                // a frustrated user cannot find it.
                Button("Settings") { isShowingSettings = true }
                    .accessibilityIdentifier("home.settings")
                    .font(.callout)
                    .foregroundStyle(Color.lumoHaze)
                    .padding(.top, 24)
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
    }
}
