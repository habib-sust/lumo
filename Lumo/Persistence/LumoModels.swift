import Foundation
import LumoCore
import SwiftData

/// The durable coin history, persisted.
///
/// SwiftData lives ONLY in the app. No extension opens it: the DeviceActivityMonitor has a 6 MB
/// ceiling and initialising a Core Data stack inside it is the documented way to get Jetsam-killed,
/// at which point the shield silently never re-applies. Extensions read the small App Group blob
/// instead.
///
/// The stored shape deliberately mirrors `LedgerEntry` rather than sharing it. `@Model` types are
/// reference types tied to a `ModelContext`, and letting one cross into the domain layer would drag
/// context lifetime and thread affinity along with it.
@Model
final class LedgerEntryRecord {
    /// Matches `LedgerEntry.id`. Not declared `@Attribute(.unique)` on purpose — see the note in
    /// `SwiftDataLedgerStore.append`.
    var entryID: UUID = UUID()
    var at: Date = Date(timeIntervalSince1970: 0)
    /// Stored as the raw string so an unknown future kind decodes rather than throwing.
    var kindRaw: String = LedgerKind.recoveryAdjustment.rawValue
    var grantedDelta: Int = 0
    var earnedDelta: Int = 0
    var intentID: UUID?
    var note: String = ""

    init(_ entry: LedgerEntry) {
        entryID = entry.id
        at = entry.at
        kindRaw = entry.kind.rawValue
        grantedDelta = entry.grantedDelta
        earnedDelta = entry.earnedDelta
        intentID = entry.intentID
        note = entry.note
    }

    /// Back to the value type the domain works with.
    ///
    /// An unrecognised `kindRaw` maps to `.recoveryAdjustment` rather than throwing: a row written by
    /// a newer build must still contribute its deltas to the fold, because dropping it would silently
    /// change the user's balance.
    var value: LedgerEntry {
        LedgerEntry(
            id: entryID,
            at: at,
            kind: LedgerKind(rawValue: kindRaw) ?? .recoveryAdjustment,
            grantedDelta: grantedDelta,
            earnedDelta: earnedDelta,
            intentID: intentID,
            note: note
        )
    }
}

/// A habit the user defined.
@Model
final class HabitRecord {
    var habitID: UUID = UUID()
    var name: String = ""
    var targetMinutes: Int = 10
    /// False for the explicit "for its own sake" list, which earns nothing by design.
    var isMonetised: Bool = true
    var createdAt: Date = Date(timeIntervalSince1970: 0)
    var isArchived: Bool = false

    init(_ spec: HabitSpec, createdAt: Date) {
        habitID = spec.id
        name = spec.name
        targetMinutes = spec.targetMinutes
        isMonetised = spec.isMonetised
        self.createdAt = createdAt
    }

    var value: HabitSpec {
        HabitSpec(id: habitID, name: name, targetMinutes: targetMinutes, isMonetised: isMonetised)
    }
}

/// One completed attempt.
@Model
final class SessionRecord {
    var habitID: UUID = UUID()
    var startedAt: Date = Date(timeIntervalSince1970: 0)
    var endedAt: Date = Date(timeIntervalSince1970: 0)
    var activeSeconds: Double = 0
    var pausedSeconds: Double = 0
    /// Recorded rather than hidden, so it can be weighted differently if it is ever abused.
    var wasRetroactive: Bool = false
    var coinsAwarded: Int = 0

    init(_ session: HabitSession, coinsAwarded: Int) {
        habitID = session.habitID
        startedAt = session.startedAt
        endedAt = session.endedAt
        activeSeconds = session.activeSeconds
        pausedSeconds = session.pausedSeconds
        wasRetroactive = session.wasRetroactive
        self.coinsAwarded = coinsAwarded
    }

    var value: HabitSession {
        HabitSession(
            habitID: habitID,
            startedAt: startedAt,
            endedAt: endedAt,
            activeSeconds: activeSeconds,
            pausedSeconds: pausedSeconds,
            wasRetroactive: wasRetroactive
        )
    }
}

/// Schema versions, frozen as they ship.
enum LumoSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [LedgerEntryRecord.self, HabitRecord.self, SessionRecord.self]
    }
}

/// Present from day one, with nothing in it.
///
/// The first migration always arrives under time pressure, alongside a feature, against real user
/// data that cannot be recreated — so the harness should already exist and be wired by then.
enum LumoMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LumoSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
