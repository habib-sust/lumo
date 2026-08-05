// Guarded so the package compiles to an empty module off-iOS, which keeps
// `swift build` working at the workspace root. Real builds target iphoneos.
//
// `os(iOS)`, not `canImport(ManagedSettings)`: the module IS importable on macOS, but
// every type in it is `@available(macOS, unavailable)` and FamilyActivitySelection is
// absent entirely — so canImport succeeds and then compilation fails.
#if os(iOS)

import DeviceActivity
import Foundation
import ManagedSettings

// NOTE: FamilyControls is deliberately NOT imported here, and must never be.
//
// FamilyControls links SwiftUI (it ships FamilyActivityPicker), which links UIKit. Because
// the DeviceActivityMonitor extension links this package, importing FamilyControls here
// gives that extension a transitive UIKit link — against a 6 MB high-watermark it dies past,
// silently, taking the shield with it.
//
// This was caught by the link-graph gate rather than by reading: the monitor extension was
// linking UIKit with no UIKit import anywhere in its own sources. `lint-imports.sh` now
// blocks the regression.
//
// The FamilyActivitySelection Sendable conformance therefore lives in the app target, which
// is the only place that presents a picker anyway.

// Apple ships ZERO Sendable conformances in ManagedSettings and DeviceActivity. Verified
// against the iOS 26.5 SDK:
//
//   grep -c Sendable .../ManagedSettings.swiftmodule/arm64e-apple-ios.swiftinterface  -> 0
//   grep -c Sendable .../DeviceActivity.swiftmodule/arm64e-apple-ios.swiftinterface   -> 0
//
// Under Swift 6 strict concurrency that makes these types unusable across isolation
// boundaries, which we unavoidably cross: the app writes a selection, three extensions
// in three separate processes read it back.
//
// This file is the ONLY place in the codebase permitted to add such a conformance, so
// the audit surface is one screen rather than scattered `@unchecked` sprinkles.
//
// Why `@unchecked` is defensible here: every one of these is an opaque, immutable value
// handle. A token is a system-issued identifier with no reachable mutable state, and the
// name/schedule/event types are value types wrapping `DateComponents`, strings and sets.
// We are asserting "this has no mutable interior," which is true for all of them.

extension Token: @retroactive @unchecked Sendable {}

extension ManagedSettingsStore.Name: @retroactive @unchecked Sendable {}

extension DeviceActivityName: @retroactive @unchecked Sendable {}
extension DeviceActivityEvent: @retroactive @unchecked Sendable {}
extension DeviceActivityEvent.Name: @retroactive @unchecked Sendable {}
extension DeviceActivitySchedule: @retroactive @unchecked Sendable {}


// DELIBERATELY ABSENT: ManagedSettingsStore.
//
// It is a live handle onto system state, not a value. Making it Sendable would invite
// passing one across processes or holding it past its useful life. Construct a store at
// the point of use, mutate it, and let it go — `ManagedSettingsStore(named:)` is cheap
// and the underlying store is shared by the system across app and extensions anyway.
//
// DELIBERATELY ABSENT: DeviceActivityCenter, for the same reason.

// MARK: - Compile-time proof the shim is in effect
//
// Family Controls cannot run in the Simulator, so there is no runtime test that would
// catch a conformance going missing here. This costs nothing and fails at build time
// instead — delete any conformance above and this stops compiling.
//
// It also guards a subtler mistake: wrapping this file in the wrong preprocessor
// condition. `canImport(ManagedSettings)` is true on macOS even though every type is
// `@available(macOS, unavailable)`, so a `canImport` guard compiles the block and then
// fails. If that regresses, this breaks immediately.

private func requiresSendable<T: Sendable>(_: T.Type) {}

private func shimSelfTest() {
    requiresSendable(ApplicationToken.self)
    requiresSendable(ActivityCategoryToken.self)
    requiresSendable(WebDomainToken.self)
    requiresSendable(ManagedSettingsStore.Name.self)
    requiresSendable(DeviceActivityName.self)
    requiresSendable(DeviceActivityEvent.self)
    requiresSendable(DeviceActivityEvent.Name.self)
    requiresSendable(DeviceActivitySchedule.self)
}

#endif
