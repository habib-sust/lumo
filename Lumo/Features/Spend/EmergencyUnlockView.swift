import LumoCore
import LumoShieldKit
import SwiftUI

/// The friction screen in front of a free unlock.
///
/// A delay plus a prominent way out — and **no motivational text**. That omission is the finding,
/// not an oversight: the one preregistered decomposition of this mechanic found the dismiss option
/// was the strongest component, the time delay also worked, and the deliberation message did
/// nothing measurable. Adding an encouraging paragraph here is a genuine temptation that the
/// evidence says buys nothing, so the space is deliberately left empty.
struct EmergencyUnlockView: View {

    let bucket: BucketID
    var onDismissed: () -> Void
    var onUnlocked: (UnlockWindow) -> Void

    @State private var remaining: Int = 0
    @State private var total: Int = 0
    @State private var failure: String?

    private let policy = FrictionPolicy.default

    var body: some View {
        ZStack {
            Color.lumoInk.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // The countdown is the whole interface. No copy telling the user how to feel.
                ZStack {
                    Circle()
                        .stroke(Color.lumoSoot, lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.lumoEmber, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(remaining)")
                        .font(.system(size: 44, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.lumoText)
                        .contentTransition(.numericText(countsDown: true))
                }
                .frame(width: 148, height: 148)
                .accessibilityLabel("\(remaining) seconds remaining")

                Text(remaining > 0 ? "Opening in a moment" : "Ready")
                    .font(.callout)
                    .foregroundStyle(Color.lumoHaze)

                if let failure {
                    Text(failure)
                        .font(.footnote)
                        .foregroundStyle(Color.lumoEmber)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Spacer()

                VStack(spacing: 12) {
                    PrimaryButton("Open for \(policy.windowMinutes) min", isBusy: false, isEnabled: remaining == 0) {
                        unlock()
                    }

                    // Available from t = 0, prominently. This is the strongest component of the
                    // mechanic, so it is never hidden behind the countdown or de-emphasised into
                    // a corner.
                    Button("Actually, never mind", action: onDismissed)
                        .font(.headline)
                        .foregroundStyle(Color.lumoHaze)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .task {
            // Read per-use so the escalation the user actually experiences matches what was
            // recorded, rather than a value cached from a previous screen.
            total = LumoStack.emergencyUnlock(for: .app)?.requiredDelaySeconds(policy: policy)
                ?? policy.escalatingDelays[0]
            remaining = total
            await countDown()
        }
    }

    private var progress: Double {
        guard total > 0 else { return 1 }
        return Double(total - remaining) / Double(total)
    }

    private func countDown() async {
        while remaining > 0 {
            try? await Task.sleep(for: .seconds(1))
            // Guard against the view going away mid-sleep.
            guard !Task.isCancelled else { return }
            withAnimation(.snappy) { remaining -= 1 }
        }
    }

    private func unlock() {
        guard let emergency = LumoStack.emergencyUnlock(for: .app) else {
            failure = "Lumo can't reach its settings right now. Reopening the app usually fixes it."
            return
        }
        do {
            let window = try emergency.grant(bucket: bucket, policy: policy)
            onUnlocked(window)
        } catch {
            // Even a failure here must not dead-end: the message says what to do next.
            failure = "Couldn't open that app. Try again, or reopen Lumo."
        }
    }
}
