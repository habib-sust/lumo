import LumoCore
import LumoShieldKit
import SwiftUI

/// On-device state inspector.
///
/// Shipped in Release, not gated to Debug. Family Controls cannot run in the Simulator, a Jetsam
/// kill of the monitor extension leaves no crash log a user would ever report, and a mis-typed App
/// Group fails silently — so this is frequently the only way to find out what is actually
/// happening, including in the hands of a user reporting a problem.
struct DebugPanelView: View {

    @State private var snapshot = DebugSnapshot.capture()
    @State private var lastAction: String?
    @Environment(AuthorizationService.self) private var authorization

    var body: some View {
        NavigationStack {
            List {
                Section("Platform") {
                    row("App Group", snapshot.appGroupAvailable ? "OK" : "MISSING",
                        isBad: !snapshot.appGroupAvailable)
                    row("Authorization", "\(authorization.status.rawValue)",
                        isBad: !authorization.isAuthorized)
                    row("Schema", snapshot.schemaVersion.map(String.init) ?? "unset")
                }

                Section("Economy") {
                    row("Granted", "\(snapshot.walletGranted)")
                    row("Earned", "\(snapshot.walletEarned)")
                    row("Journal", "\(snapshot.journalEntries)")
                }

                Section("Shielding") {
                    row("Buckets", "\(snapshot.bucketCount)")
                    row("Essential", "\(snapshot.essentialCount)")
                    row("Live windows", "\(snapshot.liveWindows)")
                    // `nil` here means the OS cannot report, which is NOT the same as "none" —
                    // spelled out because conflating them would be an easy misread.
                    row("System stores",
                        snapshot.systemStoreNames.map { "\($0.count)" } ?? "unavailable (<26.5)")
                    row("Activities", "\(snapshot.lumoActivityNames.count)")
                }

                if !snapshot.flags.isEmpty {
                    Section("Flags") {
                        ForEach(snapshot.flags, id: \.self) { flag in
                            Text(flag)
                                .font(.callout.monospaced())
                                .foregroundStyle(Color.lumoEmber)
                        }
                    }
                }

                Section("Recent events") {
                    if snapshot.recentDiagnostics.isEmpty {
                        Text("(none)").foregroundStyle(Color.lumoHaze)
                    } else {
                        ForEach(snapshot.recentDiagnostics, id: \.self) { entry in
                            Text(entry)
                                .font(.caption.monospaced())
                                .foregroundStyle(Color.lumoHaze)
                        }
                    }
                }

                Section("Actions") {
                    Button("Force reconcile") {
                        LumoStack.reconcileNow(.app)
                        snapshot = .capture()
                    }
                    Button("Refresh") { snapshot = .capture() }
                }

                Section {
                    Button("Grant 100 test coins") { grantCoins() }
                    // 2 minutes is chosen deliberately: it is BELOW iOS's 15-minute
                    // DeviceActivitySchedule floor, so it exercises the warningTime path that
                    // SPIKE-2a exists to measure. Apple documents no minimum for warningTime and
                    // the widely-repeated 15-minute figure is community lore, so whether short
                    // leads fire dependably decides whether sub-15-minute tiers can exist at all.
                    Button("Unlock slot 00 for 2 min (warningTime path)") { spend(minutes: 2) }
                    Button("Unlock slot 00 for 16 min (intervalDidEnd path)") { spend(minutes: 16) }
                    if let outcome = lastAction {
                        Text(outcome)
                            .font(.caption.monospaced())
                            .foregroundStyle(Color.lumoMoss)
                    }
                } header: {
                    Text("Loop test")
                } footer: {
                    Text("Test-only. Coins here are granted, never earned — the real economy has no way to buy them.")
                }

                Section("Container") {
                    Text(snapshot.containerPath ?? "nil")
                        .font(.caption2.monospaced())
                        .foregroundStyle(Color.lumoHaze)
                }
            }
            .navigationTitle("Debug")
            .accessibilityIdentifier("debug.root")
            .scrollContentBackground(.hidden)
            .background(Color.lumoInk)
        }
    }

    /// Grants coins into the GRANTED pot, never `earned`.
    ///
    /// Matters even in a debug tool: `earned` is the pot nothing may inflate or claw back, and a
    /// test affordance that violated that invariant would make the wallet's audit trail a lie.
    private func grantCoins() {
        guard let store = LumoStack.stateStore(for: .app),
              var state = try? store.loadState() else {
            lastAction = "no store"
            return
        }
        state.wallet.issueGrant(100)
        try? store.saveState(state)
        snapshot = .capture()
        lastAction = "granted 100 (granted pot)"
    }

    private func spend(minutes: Int) {
        guard let coordinator = LumoStack.spendCoordinator(for: .app),
              let store = LumoStack.stateStore(for: .app),
              let table = try? store.loadBuckets() else {
            lastAction = "no coordinator"
            return
        }
        let bucket = BucketID(slot: 0)
        guard table.buckets[bucket] != nil else {
            lastAction = "slot 00 empty — pick apps first"
            return
        }

        let policy = Policy.default
        let offer = SpendCoordinator.Offer(
            bucket: bucket,
            price: policy.price(forMinutes: minutes),
            windowSeconds: TimeInterval(minutes * 60),
            usageBudgetSeconds: TimeInterval(minutes * 60),
            tierIndex: 0,
            policyFingerprint: policy.fingerprint
        )
        do {
            let receipt = try coordinator.spend(offer)
            lastAction = "unlocked \(minutes)m, \(offer.price) coins, ends \(receipt.window.endsAt.formatted(date: .omitted, time: .standard))"
        } catch {
            lastAction = "spend failed: \(error)"
        }
        snapshot = .capture()
    }

    private func row(_ label: String, _ value: String, isBad: Bool = false) -> some View {
        HStack {
            Text(label).foregroundStyle(.white)
            Spacer()
            Text(value)
                .font(.callout.monospaced())
                .foregroundStyle(isBad ? Color.lumoEmber : Color.lumoMoss)
        }
    }
}
