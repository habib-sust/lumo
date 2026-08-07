#if os(iOS)

import DeviceActivity
import Foundation
import LumoCore
import ManagedSettings

/// Everything worth knowing about the live system, in one value.
///
/// This exists because Family Controls cannot run in the Simulator, so on-device inspection is
/// frequently the *only* diagnostic available. A Jetsam kill of the monitor extension leaves no
/// crash log a user would ever report, and a mis-typed App Group fails silently — both are
/// invisible without something like this.
public struct DebugSnapshot: Sendable {

    public var appGroupAvailable: Bool
    public var appGroupIdentifier: String
    public var containerPath: String?
    public var schemaVersion: Int?

    public var walletGranted: Int
    public var walletEarned: Int
    public var bucketCount: Int
    public var essentialCount: Int
    public var liveWindows: Int
    public var journalEntries: Int
    public var flags: [String]

    /// Store names the system reports (iOS 26.5+). `nil` means the OS cannot tell us — which must
    /// never be read as "none exist".
    public var systemStoreNames: [String]?
    public var lumoActivityNames: [String]
    public var recentDiagnostics: [String]

    public static func capture() -> DebugSnapshot {
        let defaults = LumoStack.defaults
        var snapshot = DebugSnapshot(
            appGroupAvailable: defaults != nil,
            appGroupIdentifier: AppGroup.identifier,
            containerPath: FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?.path,
            schemaVersion: nil,
            walletGranted: 0,
            walletEarned: 0,
            bucketCount: 0,
            essentialCount: 0,
            liveWindows: 0,
            journalEntries: 0,
            flags: [],
            systemStoreNames: nil,
            lumoActivityNames: [],
            recentDiagnostics: []
        )

        if let store = LumoStack.stateStore(for: .app) {
            snapshot.schemaVersion = store.loadSchemaVersion()
            if let state = try? store.loadState() {
                snapshot.walletGranted = state.wallet.granted
                snapshot.walletEarned = state.wallet.earned
                snapshot.liveWindows = state.openBuckets(now: Date()).count
                snapshot.journalEntries = state.journal.count
                snapshot.flags = Self.describe(state.flags)
            }
            if let table = try? store.loadBuckets() {
                snapshot.bucketCount = table.buckets.count
                snapshot.essentialCount = table.essential.count
            }
        }

        if #available(iOS 26.5, *) {
            snapshot.systemStoreNames = ManagedSettingsStore.stores.map(\.rawValue).sorted()
        }

        snapshot.lumoActivityNames = DeviceActivityCenter().activities
            .map(\.rawValue)
            .filter { $0.hasPrefix(LiveActivityScheduler.namePrefix) }
            .sorted()

        if let defaults {
            snapshot.recentDiagnostics = RingBufferDiagnostics.load(from: defaults)
                .entries.suffix(12)
                .map { "[\($0.process.rawValue)] \($0.event) \($0.detail)" }
        }

        return snapshot
    }

    private static func describe(_ flags: Flags) -> [String] {
        var names: [String] = []
        if flags.contains(.safeMode) { names.append("safeMode") }
        if flags.contains(.needsMigration) { names.append("needsMigration") }
        if flags.contains(.tokenDriftDetected) { names.append("tokenDrift") }
        if flags.contains(.authorizationLost) { names.append("authorizationLost") }
        if flags.contains(.thresholdUntrusted) { names.append("thresholdUntrusted") }
        if flags.contains(.activityBudgetFull) { names.append("activityBudgetFull") }
        return names
    }

    /// Plain-text dump.
    ///
    /// Printed to stdout at launch in debug builds specifically so `devicectl --console` can
    /// capture it — os_log does not reach stdout, and on-device state is otherwise unreadable from
    /// a development machine.
    public var report: String {
        var lines: [String] = ["── LUMO DEBUG SNAPSHOT ──"]
        lines.append("appGroup:        \(appGroupAvailable ? "OK" : "MISSING") \(appGroupIdentifier)")
        lines.append("container:       \(containerPath ?? "nil")")
        lines.append("schemaVersion:   \(schemaVersion.map(String.init) ?? "unset")")
        lines.append("wallet:          granted \(walletGranted), earned \(walletEarned)")
        lines.append("buckets:         \(bucketCount) shieldable, \(essentialCount) essential")
        lines.append("liveWindows:     \(liveWindows)")
        lines.append("journal:         \(journalEntries)")
        lines.append("flags:           \(flags.isEmpty ? "none" : flags.joined(separator: ","))")
        lines.append("systemStores:    \(systemStoreNames.map { $0.isEmpty ? "[] (none)" : $0.joined(separator: ",") } ?? "unavailable (<26.5)")")
        lines.append("lumoActivities:  \(lumoActivityNames.isEmpty ? "none" : lumoActivityNames.joined(separator: ","))")
        lines.append("diagnostics:")
        if recentDiagnostics.isEmpty {
            lines.append("  (empty)")
        } else {
            lines.append(contentsOf: recentDiagnostics.map { "  \($0)" })
        }
        lines.append("─────────────────────────")
        return lines.joined(separator: "\n")
    }
}

#endif
