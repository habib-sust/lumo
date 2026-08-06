#if os(iOS)

import Foundation
import LumoCore
import ManagedSettings

/// `ShieldStoring` over real `ManagedSettingsStore`s — one named store per bucket.
///
/// Uses `shield.applications`, never `application.blockedApplications`. A hard block would
/// remove the shield UI entirely, and the shield is the *only* surface where a user can spend
/// coins — so it would silently delete the product's business model. There is a merge-blocking
/// CI grep for `blockedApplications` to keep that decision from eroding.
public struct LiveShieldStore: ShieldStoring {

    private let diagnostics: any Diagnosing

    public init(diagnostics: any Diagnosing = NullDiagnostics()) {
        self.diagnostics = diagnostics
    }

    public enum ShieldError: Error, Equatable {
        /// The stored bytes no longer decode to a usable token — iOS reissued it.
        case tokenUnreadable(BucketID)
    }

    private func store(for bucket: BucketID) -> ManagedSettingsStore {
        // Cheap to construct, and the system shares the underlying store across the app and
        // all extensions, so there is nothing to cache and nothing to keep alive.
        ManagedSettingsStore(named: .init(bucket.storeNameRaw))
    }

    // MARK: - Shield

    public func shield(_ bucket: BucketID, token: TokenBlob, kind: BucketKind) throws {
        let target = store(for: bucket)

        switch kind {
        case .application:
            guard let resolved = try? TokenCodec.applicationToken(from: token) else {
                diagnostics.record("shield.tokenUnreadable", detail: bucket.storeNameRaw)
                throw ShieldError.tokenUnreadable(bucket)
            }
            // A one-token set, because a bucket is exactly one token. Assigning a set rather
            // than nil is what "configured" means here.
            target.shield.applications = [resolved]

        case .category:
            guard let resolved = try? TokenCodec.categoryToken(from: token) else {
                diagnostics.record("shield.tokenUnreadable", detail: bucket.storeNameRaw)
                throw ShieldError.tokenUnreadable(bucket)
            }
            target.shield.applicationCategories = .specific([resolved])
        }

        if #available(iOS 26.5, *) {
            // Belt and braces: a store that was deactivated by a previous unlock must be
            // reactivated, or the shield we just wrote would have no effect.
            target.isActive = true
        }
    }

    // MARK: - Unshield

    /// Temporarily opens a bucket. The tokens stay in place.
    ///
    /// On iOS 26.5+ this flips `isActive` rather than clearing the token sets, which is
    /// materially better: tokens never move between stores, so the documented stale-shield bug
    /// — where a migrated token leaves the shield UI rendering a dead block — cannot occur.
    /// Below 26.5 we clear and re-apply, which is why the reconciler keeps a mirror.
    public func unshield(_ bucket: BucketID) throws {
        let target = store(for: bucket)
        if #available(iOS 26.5, *) {
            target.isActive = false
        } else {
            target.clearAllSettings()
        }
    }

    // MARK: - Destroy

    /// Permanent teardown for a bucket that no longer exists.
    ///
    /// Distinct from `unshield` on purpose: unshielding is a paid, temporary state the
    /// reconciler will undo, whereas this is for an app the user removed from their blocklist.
    /// Conflating them would let a removed app be silently re-shielded.
    public func destroy(_ bucket: BucketID) throws {
        let target = store(for: bucket)
        target.clearAllSettings()
        if #available(iOS 26.5, *) {
            // Reactivate before deleting so a resurrected store name never starts life
            // inactive, and free the slot properly rather than leaving an empty store behind
            // against the 50-store limit.
            target.isActive = true
            target.deleteStore()
        }
    }

    // MARK: - Introspection

    /// `nil` means "this OS cannot tell us", which callers must NOT read as "no stores exist"
    /// — that would let us conclude the user has no shields at all and act on it.
    public func knownStoreNames() -> Set<String>? {
        if #available(iOS 26.5, *) {
            return Set(ManagedSettingsStore.stores.map(\.rawValue))
        }
        return nil
    }
}

#endif
