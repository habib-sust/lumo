import FamilyControls
import Foundation
import LumoCore
import LumoShieldKit
import ManagedSettings
import Observation
import SwiftUI

/// What the hearth needs to draw itself.
///
/// A value type rather than a stream of live queries, because everything here is read under one
/// cross-process lock: reading the wallet, the windows and the bucket table in three separate passes
/// would let a monitor-extension write land between them and render a screen that never existed.
struct HearthSnapshot: Equatable {
    var wallet: Wallet = .zero
    var policy: Policy = .default
    /// Buckets that are locked right now, in slot order.
    var locked: [Bucket] = []
    /// Buckets with a live paid window, and when it ends.
    var open: [(bucket: Bucket, endsAt: Date)] = []
    var calibration: BaselineCalibration = .empty
    var isSafeMode = false

    static func == (lhs: HearthSnapshot, rhs: HearthSnapshot) -> Bool {
        lhs.wallet == rhs.wallet
            && lhs.policy == rhs.policy
            && lhs.locked == rhs.locked
            && lhs.open.map(\.bucket) == rhs.open.map(\.bucket)
            && lhs.open.map(\.endsAt) == rhs.open.map(\.endsAt)
            && lhs.calibration == rhs.calibration
            && lhs.isSafeMode == rhs.isSafeMode
    }

    var warmth: Double { LightRadius.warmth(forBalance: wallet.total) }

    var mood: BuddyMood { .forWarmth(warmth) }

    /// The soonest window to expire, which is the one the countdown shows.
    var nextExpiry: Date? { open.map(\.endsAt).min() }
}

@MainActor
@Observable
final class HearthModel {

    private(set) var snapshot = HearthSnapshot()

    /// Set briefly after a spend or an award, to drive the one bold moment.
    private(set) var surge: Double = 0

    func refresh() {
        guard let store = LumoStack.stateStore(for: .app) else { return }
        // One read of each payload, then compose. `loadState` already returns a single atomic blob,
        // which is the whole reason shared state is one key rather than five.
        guard let state = try? store.loadState(), let table = try? store.loadBuckets() else {
            snapshot.isSafeMode = true
            return
        }

        let now = Date()
        let openWindows = state.windows.filter { $0.isLive(now: now) }
        let openSlots = Set(openWindows.map(\.bucket))

        var next = HearthSnapshot()
        next.wallet = state.wallet
        next.policy = store.loadPolicy()
        next.calibration = state.baseline
        next.isSafeMode = state.flags.contains(.safeMode)
        next.locked = table.buckets.values
            .filter { !openSlots.contains($0.id) }
            .sorted { $0.id.slot < $1.id.slot }
        next.open = openWindows
            .compactMap { window in
                table.buckets[window.bucket].map { (bucket: $0, endsAt: window.endsAt) }
            }
            .sorted { $0.bucket.id.slot < $1.bucket.id.slot }

        snapshot = next
    }

    /// Flashes the light. Self-clearing, so no caller has to remember to turn it off.
    func flash() {
        surge = 0.35
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            surge = 0
        }
    }
}

// MARK: - Token rendering

/// Renders an app or category using the system's own out-of-process view.
///
/// `Label(token)` is the ONLY way to show what a shielded app actually is. Tokens are opaque by
/// design: the name and icon are never readable as a `String` or `Image` in this process, so price
/// text is composed *beside* the label and never interpolated into it. Anything claiming to print
/// "TikTok — 25 coins" as one string is either wrong or reading something it should not.
struct BucketLabel: View {
    let bucket: Bucket

    var body: some View {
        Group {
            switch bucket.kind {
            case .application:
                if let token = try? TokenCodec.applicationToken(from: bucket.token) {
                    Label(token)
                } else {
                    fallback
                }
            case .category:
                if let token = try? TokenCodec.categoryToken(from: bucket.token) {
                    Label(token)
                } else {
                    fallback
                }
            }
        }
        .labelStyle(.iconOnly)
    }

    /// A token that will not resolve means iOS reissued it — the rotation bug every competitor in
    /// this category eats 1★ reviews for. Show a truthful placeholder rather than an empty gap, so
    /// the repair banner elsewhere has something the user can connect it to.
    private var fallback: some View {
        RoundedRectangle(cornerRadius: LumoRadius.tile, style: .continuous)
            .fill(Color.lumoSoot)
            .overlay {
                Image(systemName: "questionmark")
                    .foregroundStyle(Color.lumoHaze)
            }
    }
}
