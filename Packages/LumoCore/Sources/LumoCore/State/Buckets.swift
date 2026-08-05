import Foundation

/// A portable stand-in for an opaque system token (`ApplicationToken`,
/// `ActivityCategoryToken`, …).
///
/// LumoCore never imports ManagedSettings, so tokens cross this boundary as bytes.
/// LumoShieldKit owns the encode/decode.
///
/// Identity is NEVER derived from these bytes. iOS reissues tokens unpredictably —
/// independently reported by the developers of ScreenZen, Jomo and Opal — so a token is
/// a payload, not a name. The bucket *slot* is the identity.
public struct TokenBlob: Hashable, Codable, Sendable {
    public let raw: Data

    public init(raw: Data) {
        self.raw = raw
    }
}

/// A stable slot number. This, not the token bytes, is a bucket's identity.
///
/// Slots never migrate once assigned. That is what makes the stale-shield variant of the
/// token-rotation bug structurally impossible: a token that changes value keeps its slot,
/// so no shield ever has to move between stores.
public struct BucketID: Hashable, Codable, Sendable, Comparable {
    /// `0..<48` — the application cap (40) plus the category cap (8).
    public let slot: Int

    public init(slot: Int) {
        self.slot = slot
    }

    /// The `ManagedSettingsStore` name for this bucket. Zero-padded so store names sort
    /// lexicographically in the same order as slots, which makes the debug panel readable.
    public var storeNameRaw: String {
        String(format: "lumo.bucket.%02d", slot)
    }

    public static func < (a: Self, b: Self) -> Bool { a.slot < b.slot }
}

// Encodes a `[BucketID: Bucket]` dictionary as a keyed JSON object ("00", "01", …)
// rather than Swift's default flat [key, value, key, value] array.
//
// This matters because dumping the raw lumo.* JSON is a first-class debugging tool —
// Family Controls cannot run in the Simulator, so reading state by eye on a device is
// often the only diagnostic available.
extension BucketID: CodingKeyRepresentable {
    public init?<T: CodingKey>(codingKey: T) {
        guard let slot = Int(codingKey.stringValue) else { return nil }
        self.init(slot: slot)
    }

    public var codingKey: any CodingKey {
        SlotCodingKey(slot: slot)
    }

    private struct SlotCodingKey: CodingKey {
        let stringValue: String
        var intValue: Int? { Int(stringValue) }

        init(slot: Int) { stringValue = String(format: "%02d", slot) }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { stringValue = String(format: "%02d", intValue) }
    }
}

public enum BucketKind: String, Codable, Sendable {
    case application
    case category
}

/// One shieldable thing, in one named store.
///
/// A bucket holds exactly ONE token. Multi-app buckets over-deliver — pay for TikTok,
/// get Instagram free — which drives the effective price below the user's baseline ratio.
/// Below that ratio the contingency stops reinforcing and becomes a punisher, suppressing
/// the very habit the economy exists to build.
public struct Bucket: Codable, Sendable, Equatable {
    public var id: BucketID
    public var kind: BucketKind
    public var token: TokenBlob
    public var addedAt: Date

    /// Captured opportunistically if the shield-config extension ever sees a populated
    /// `Application.localizedDisplayName`. Display-only — never used for identity or logic,
    /// and never sent anywhere.
    public var observedDisplayName: String?

    public init(
        id: BucketID,
        kind: BucketKind,
        token: TokenBlob,
        addedAt: Date,
        observedDisplayName: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.token = token
        self.addedAt = addedAt
        self.observedDisplayName = observedDisplayName
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(BucketID.self, forKey: .id) ?? BucketID(slot: 0)
        kind = try c.decodeIfPresent(BucketKind.self, forKey: .kind) ?? .application
        token = try c.decodeIfPresent(TokenBlob.self, forKey: .token) ?? TokenBlob(raw: Data())
        addedAt = try c.decodeIfPresent(Date.self, forKey: .addedAt) ?? Date(timeIntervalSince1970: 0)
        observedDisplayName = try c.decodeIfPresent(String.self, forKey: .observedDisplayName)
    }
}

public struct BucketTable: Codable, Sendable, Equatable {
    public var buckets: [BucketID: Bucket]

    /// Tokens that must never be shielded, subtracted at every write.
    ///
    /// This is the essential-apps deny-set. It is enforced inside the reconciler rather
    /// than only in the picker, so a token cannot become shielded by any route.
    public var essential: Set<TokenBlob>

    /// 40, not 50. iOS fails **silently and totally** at 51 shielded tokens — there is no
    /// error to catch, `MonitoringError` has no token-count case — so we keep headroom
    /// under both that cliff and the 50-named-store limit.
    public var maxApplicationTokens: Int

    /// Categories over-deliver by construction, so they are capped hard and priced higher.
    /// They exist only as the escape route past the application cap.
    public var maxCategoryTokens: Int

    public var lastPickerCommitAt: Date?

    public init(
        buckets: [BucketID: Bucket] = [:],
        essential: Set<TokenBlob> = [],
        maxApplicationTokens: Int = BucketTable.defaultMaxApplicationTokens,
        maxCategoryTokens: Int = BucketTable.defaultMaxCategoryTokens,
        lastPickerCommitAt: Date? = nil
    ) {
        self.buckets = buckets
        self.essential = essential
        self.maxApplicationTokens = maxApplicationTokens
        self.maxCategoryTokens = maxCategoryTokens
        self.lastPickerCommitAt = lastPickerCommitAt
    }

    public static let defaultMaxApplicationTokens = 40
    public static let defaultMaxCategoryTokens = 8

    /// Total addressable slots, and therefore the valid range of `BucketID.slot`.
    public static var slotCapacity: Int {
        defaultMaxApplicationTokens + defaultMaxCategoryTokens
    }

    public static let empty = BucketTable()

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        buckets = try c.decodeIfPresent([BucketID: Bucket].self, forKey: .buckets) ?? [:]
        essential = try c.decodeIfPresent(Set<TokenBlob>.self, forKey: .essential) ?? []
        maxApplicationTokens = try c.decodeIfPresent(Int.self, forKey: .maxApplicationTokens)
            ?? Self.defaultMaxApplicationTokens
        maxCategoryTokens = try c.decodeIfPresent(Int.self, forKey: .maxCategoryTokens)
            ?? Self.defaultMaxCategoryTokens
        lastPickerCommitAt = try c.decodeIfPresent(Date.self, forKey: .lastPickerCommitAt)
    }
}
