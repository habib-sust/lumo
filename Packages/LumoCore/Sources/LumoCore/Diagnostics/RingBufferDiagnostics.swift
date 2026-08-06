import Foundation

/// One breadcrumb.
public struct DiagEntry: Codable, Sendable, Equatable {
    public var at: Date
    public var process: ProcessTag
    public var event: String
    public var detail: String

    public init(at: Date, process: ProcessTag, event: String, detail: String) {
        self.at = at
        self.process = process
        self.event = event
        // Truncated at the boundary rather than trusted: an unbounded detail string is the
        // easy way to blow the size budget from a call site that looks harmless.
        self.detail = String(detail.prefix(120))
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        at = try c.decodeIfPresent(Date.self, forKey: .at) ?? Date(timeIntervalSince1970: 0)
        process = try c.decodeIfPresent(ProcessTag.self, forKey: .process) ?? .app
        event = try c.decodeIfPresent(String.self, forKey: .event) ?? ""
        detail = try c.decodeIfPresent(String.self, forKey: .detail) ?? ""
    }
}

/// A bounded ring of breadcrumbs, shared across processes.
///
/// This is the **only field telemetry available for the monitor extension**. A Jetsam kill at
/// its 6 MB ceiling leaves no crash log a user would ever think to report, so without a
/// durable ring the failure is completely invisible — the shield simply stops working and
/// nobody can say why.
///
/// Correspondingly it must never be able to cause the failure it is meant to observe: bounded
/// entries, truncated details, no throwing, and it never gates logic.
public struct DiagRing: Codable, Sendable, Equatable {
    public var entries: [DiagEntry]

    /// 64 entries × ~120 bytes keeps this comfortably inside a few KB.
    public static let capacity = 64

    public init(entries: [DiagEntry] = []) {
        self.entries = Array(entries.suffix(Self.capacity))
    }

    public static let empty = DiagRing()

    public mutating func append(_ entry: DiagEntry) {
        entries.append(entry)
        if entries.count > Self.capacity {
            entries.removeFirst(entries.count - Self.capacity)
        }
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decoded = try c.decodeIfPresent([DiagEntry].self, forKey: .entries) ?? []
        entries = Array(decoded.suffix(Self.capacity))
    }
}

/// Persists breadcrumbs into a `UserDefaults` suite.
///
/// Every operation is best-effort and silent on failure. Diagnostics that can throw, block, or
/// grow without bound turn an observability aid into an outage.
public struct RingBufferDiagnostics: Diagnosing, @unchecked Sendable {

    private let defaults: UserDefaults
    private let process: ProcessTag
    private let clock: any NowProviding

    public init(defaults: UserDefaults, process: ProcessTag, clock: any NowProviding = SystemNow()) {
        self.defaults = defaults
        self.process = process
        self.clock = clock
    }

    public func record(_ event: String, detail: String) {
        var ring = Self.load(from: defaults)
        ring.append(DiagEntry(at: clock.now, process: process, event: event, detail: detail))
        // No lock: a lost breadcrumb under a race is an acceptable cost, whereas contending
        // for the state lock from a logging call is not.
        if let data = try? JSONEncoder().encode(ring) {
            defaults.set(data, forKey: StateKey.diagnostics)
        }
    }

    public static func load(from defaults: UserDefaults) -> DiagRing {
        guard let data = defaults.data(forKey: StateKey.diagnostics),
              let ring = try? JSONDecoder().decode(DiagRing.self, from: data)
        else { return .empty }
        return ring
    }
}
