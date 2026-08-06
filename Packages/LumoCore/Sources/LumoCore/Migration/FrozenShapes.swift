import Foundation

// Frozen historical shapes.
//
// Once a schema version ships, its struct is copied here and NEVER edited again. Migrations
// decode into these rather than into the live types, because a migration written against the
// current shape quietly changes meaning the next time that shape evolves — and it would do so
// against real user data that cannot be re-created.
//
// v1 is the shipping version, so `SharedState_v1` is currently identical to `SharedState`. The
// duplication looks redundant today and stops looking redundant the moment v2 exists.

/// Schema v1 of the hot shared state. **Frozen.**
public struct SharedState_v1: Codable, Sendable, Equatable {
    public var version: Int
    public var wallet: Wallet
    public var week: WeekLedger
    public var windows: [UnlockWindow]
    public var journal: [SpendIntent]
    public var mirror: ShieldMirror
    public var flags: Flags
    public var lastReconcileAt: Date?
    public var lastReconcileBy: ProcessTag?
    public var pendingSpendRequest: SharedState.PendingSpendRequest?

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        wallet = try c.decodeIfPresent(Wallet.self, forKey: .wallet) ?? .zero
        week = try c.decodeIfPresent(WeekLedger.self, forKey: .week) ?? .empty
        windows = try c.decodeIfPresent([UnlockWindow].self, forKey: .windows) ?? []
        journal = try c.decodeIfPresent([SpendIntent].self, forKey: .journal) ?? []
        mirror = try c.decodeIfPresent(ShieldMirror.self, forKey: .mirror) ?? .empty
        flags = try c.decodeIfPresent(Flags.self, forKey: .flags) ?? []
        lastReconcileAt = try c.decodeIfPresent(Date.self, forKey: .lastReconcileAt)
        lastReconcileBy = try c.decodeIfPresent(ProcessTag.self, forKey: .lastReconcileBy)
        pendingSpendRequest = try c.decodeIfPresent(
            SharedState.PendingSpendRequest.self, forKey: .pendingSpendRequest)
    }
}

// When v2 arrives, the step looks like this — decode the frozen shape, construct the new one,
// re-encode. Nothing pokes at JSON keys.
//
//     MigrationStep(from: 1, to: 2) { data in
//         let old = try JSONDecoder().decode(SharedState_v1.self, from: data)
//         let new = SharedState_v2(migrating: old)
//         return try JSONEncoder().encode(new)
//     }
