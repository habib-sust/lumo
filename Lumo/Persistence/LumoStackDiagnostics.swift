import Foundation
import LumoCore
import LumoShieldKit

/// Small shim so app-layer persistence can record breadcrumbs without threading a `Diagnosing`
/// through every static call site.
///
/// Deliberately best-effort and non-throwing: diagnostics that can fail turn an observability aid
/// into the outage they were meant to reveal.
enum LumoStackDiagnostics {
    static func record(_ event: String, detail: String) {
        LumoStack.diagnostics(for: .app).record(event, detail: detail)
    }
}
