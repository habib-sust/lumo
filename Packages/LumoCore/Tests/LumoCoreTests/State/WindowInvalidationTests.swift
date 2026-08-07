import Foundation
import Testing
@testable import LumoCore

/// T-REASSIGN-01…06.
///
/// Regression tests for a bug found only on device: slots are reused, and windows reference SLOTS
/// rather than tokens, so a freshly-assigned slot could inherit a live paid window from whatever
/// previously occupied it. In practice a newly locked app was silently open.
@Suite("Window invalidation on slot reassignment")
struct WindowInvalidationTests {

    private func window(slot: Int, endsAt: Date = Date.fixture.addingTimeInterval(900)) -> UnlockWindow {
        UnlockWindow(
            bucket: BucketID(slot: slot),
            startedAt: .fixture,
            endsAt: endsAt,
            usageBudget: 900,
            activityName: "lumo.unlock.\(UUID().uuidString)",
            origin: .purchased,
            intentID: UUID()
        )
    }

    @Test("A window on a reassigned slot is dropped")
    func reassignedSlotLosesItsWindow() {
        var state = SharedState(windows: [window(slot: 0), window(slot: 1)])
        let dropped = state.invalidateWindows(forReassignedSlots: [BucketID(slot: 1)])

        #expect(dropped == 1)
        #expect(state.windows.map(\.bucket.slot) == [0], "only the reassigned slot loses its window")
    }

    @Test("Untouched slots keep their windows")
    func untouchedSlotsAreUnaffected() {
        // Re-picking must not cancel a window the user is currently using for an app that stayed.
        var state = SharedState(windows: [window(slot: 0), window(slot: 3)])
        #expect(state.invalidateWindows(forReassignedSlots: []) == 0)
        #expect(state.windows.count == 2)
    }

    @Test("The mirror forgets reassigned slots too")
    func mirrorIsClearedForReassignedSlots() {
        // Without this the reconciler believes the slot is already in its desired state and skips
        // the write — so the new app would stay unshielded even after the window is gone.
        var state = SharedState(
            windows: [window(slot: 1)],
            mirror: ShieldMirror(
                shielded: [BucketID(slot: 0)],
                unshielded: [BucketID(slot: 1)]
            )
        )

        state.invalidateWindows(forReassignedSlots: [BucketID(slot: 1)])

        #expect(!state.mirror.unshielded.contains(BucketID(slot: 1)))
        #expect(state.mirror.shielded.contains(BucketID(slot: 0)), "unrelated slots survive")
    }

    @Test("Invalidation is idempotent")
    func invalidationIsIdempotent() {
        var state = SharedState(windows: [window(slot: 2)])
        #expect(state.invalidateWindows(forReassignedSlots: [BucketID(slot: 2)]) == 1)
        #expect(state.invalidateWindows(forReassignedSlots: [BucketID(slot: 2)]) == 0)
    }

    @Test("After invalidation the reconciler re-shields the slot")
    func reconcilerReshieldsAfterInvalidation() throws {
        // End-to-end: this is the observed symptom — a newly locked app that was open for free.
        let clock = MutableNow(.fixture)
        let table = try BucketPartitioner.commit(
            applications: [TokenBlob(raw: Data([9])), TokenBlob(raw: Data([8]))],
            categories: [], into: .empty, now: clock.now
        ).table

        var state = SharedState(windows: [window(slot: 1)])
        state.mirror = ShieldMirror(shielded: [BucketID(slot: 0)], unshielded: [BucketID(slot: 1)])

        let store = FakeStateStore(state: state, buckets: table)
        let shields = FakeShieldStore()
        let reconciler = ShieldReconciler(
            state: store, shields: shields, scheduler: FakeActivityScheduler(),
            lock: ImmediateLock(), clock: clock
        )

        // Before: slot 1 has a live window, so the reconciler correctly leaves it open.
        reconciler.reconcile(by: .app)
        #expect(!shields.shielded.contains(BucketID(slot: 1)))

        // Slot 1 gets reassigned to a different app.
        var updated = store.currentState
        updated.invalidateWindows(forReassignedSlots: [BucketID(slot: 1)])
        try store.saveState(updated)

        reconciler.reconcile(by: .app)
        #expect(shields.shielded.contains(BucketID(slot: 1)), "the new app must be shielded")
    }

    @Test("An emergency window is invalidated the same way")
    func emergencyWindowsAlsoInvalidated() {
        // No special case: a free window on a reassigned slot is just as wrong as a paid one.
        var state = SharedState(windows: [
            UnlockWindow(
                bucket: BucketID(slot: 4), startedAt: .fixture,
                endsAt: Date.fixture.addingTimeInterval(900), usageBudget: 900,
                activityName: "lumo.unlock.x", origin: .emergency, intentID: UUID()
            ),
        ])
        #expect(state.invalidateWindows(forReassignedSlots: [BucketID(slot: 4)]) == 1)
    }
}
