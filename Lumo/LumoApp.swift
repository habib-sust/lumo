//
//  LumoApp.swift
//  Lumo
//

import SwiftUI

@main
struct LumoApp: App {

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
    //
    // TODO(T-029/T-056): call ShieldReconciler.reconcile(reason: .appLaunch) here once
    // LumoCore lands, then create the ModelContainer.
    init() {
        // Intentionally empty for now — see above.
    }

    var body: some Scene {
        WindowGroup {
            PlaceholderView()
        }
    }
}

/// Temporary launch surface for Phase 0. Replaced by the hearth in Phase 4 (T-082).
private struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Lumo")
                .font(.largeTitle.weight(.semibold))
            Text("Light comes first.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    PlaceholderView()
}
