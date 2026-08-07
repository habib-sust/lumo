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

                Section {
                    Button("Force reconcile") {
                        LumoStack.reconcileNow(.app)
                        snapshot = .capture()
                    }
                    Button("Refresh") { snapshot = .capture() }
                }

                Section("Container") {
                    Text(snapshot.containerPath ?? "nil")
                        .font(.caption2.monospaced())
                        .foregroundStyle(Color.lumoHaze)
                }
            }
            .navigationTitle("Debug")
            .scrollContentBackground(.hidden)
            .background(Color.lumoInk)
        }
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
