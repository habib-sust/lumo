import FamilyControls
import Foundation

// `FamilyActivitySelection`'s Sendable conformance lives in the APP target, not in
// LumoShieldKit, and that placement is load-bearing rather than tidiness.
//
// FamilyControls links SwiftUI (it ships FamilyActivityPicker), and SwiftUI links UIKit.
// LumoShieldKit is linked by the DeviceActivityMonitor extension, so a FamilyControls import
// there gave that extension a transitive UIKit link — against a 6 MB high-watermark it dies
// past, silently, and when it dies the shield never re-applies.
//
// The app is the only process that presents a picker or requests authorization, so this is
// also where it belongs on the merits. `lint-imports.sh` blocks FamilyControls from
// reappearing in LumoShieldKit.
//
// Apple ships no Sendable conformance for this type; the selection is an immutable value
// wrapping sets of opaque tokens, so `@unchecked` is a true assertion here.
extension FamilyActivitySelection: @retroactive @unchecked Sendable {}
