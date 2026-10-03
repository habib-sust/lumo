import LumoCore
import SwiftUI

/// The running session.
///
/// Deliberately calm. No countdown urgency, no "don't give up" copy, and no penalty for stopping —
/// the friction literature found the deliberation message did nothing while the dismiss option did
/// the work, and this screen follows the same rule: make leaving easy and say nothing about it.
struct RunningTimerView: View {

    @Environment(HabitService.self) private var habits
    @Environment(\.dismiss) private var dismiss

    @ScaledMetric(relativeTo: .largeTitle) private var timerSize = 64
    @State private var isConfirmingAbandon = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lumoInk.ignoresSafeArea()
                if let timer = habits.timer, let habit = habits.runningHabit {
                    content(timer: timer, habit: habit)
                } else {
                    // The timer can vanish underneath this view — finished in another sheet, or
                    // cleared by a corrupt-payload reset. Say so rather than showing 00:00 forever.
                    Text("Nothing is running.")
                        .lumoSecondary()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Stop without finishing?", isPresented: $isConfirmingAbandon) {
                Button("Keep going", role: .cancel) {}
                Button("Stop", role: .destructive) {
                    habits.abandon()
                    dismiss()
                }
            } message: {
                Text("This session won't count. Nothing else changes — your coins and streak stay exactly as they are.")
            }
        }
    }

    private func content(timer: HabitTimer, habit: HabitSpec) -> some View {
        // Scoped to the clock so the surrounding layout is not rebuilt every second.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = timer.activeSeconds(now: context.date)
            let met = timer.hasMetStandard(now: context.date)

            ScrollView {
                VStack(spacing: LumoSpace.loose) {
                    Label(timer.isPaused ? "Session paused" : "Time for yourself", systemImage: timer.isPaused ? "pause.circle" : "leaf")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.lumoHaze)
                        .padding(.top, 32)
                    Text(habit.name)
                        .font(.lumoTitle)
                        .foregroundStyle(Color.lumoText)

                    Text(Self.clock(elapsed))
                        .font(.system(size: timerSize, weight: .medium, design: .monospaced))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity)
                        .background(Color.lumoSoot, in: RoundedRectangle(cornerRadius: 28))
                        .foregroundStyle(met ? Color.lumoMoss : Color.lumoFlare)
                        .accessibilityIdentifier("timer.elapsed")
                        .contentTransition(.numericText())

                    Text(
                        met
                            ? "You've passed your target. Finish whenever you like."
                            : "\(habit.targetMinutes) min target"
                    )
                    .lumoSecondary()

                    if timer.isPaused {
                        Text("Paused")
                            .font(.lumoCaption)
                            .foregroundStyle(Color.lumoHaze)
                    }

                    Spacer()
                    controls(timer: timer, met: met)
                }
                .padding(LumoSpace.margin)
            }
        }
    }

    private func controls(timer: HabitTimer, met: Bool) -> some View {
        VStack(spacing: LumoSpace.snug) {
            PrimaryButton(met ? "Finish and collect" : "Finish", isBusy: false) {
                habits.finish()
                dismiss()
            }
            .accessibilityIdentifier("timer.finish")

            HStack(spacing: LumoSpace.snug) {
                Button(timer.isPaused ? "Resume" : "Pause") {
                    timer.isPaused ? habits.resume() : habits.pause()
                }
                .buttonStyle(.bordered)
                .tint(Color.lumoHaze)
                .accessibilityIdentifier("timer.pause")

                Button("Stop") { isConfirmingAbandon = true }
                    .buttonStyle(.bordered)
                    .tint(Color.lumoHaze)
            }
        }
    }

    /// `mm:ss` under an hour, `h:mm:ss` past it.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%02d:%02d", minutes, secs)
    }
}

/// Shown after a session settles.
///
/// The point is the **detail line**, not the number. Pairing a reward with informational competence
/// feedback is one of the mitigations with a real positive effect size; a bare counter going up is
/// the version the literature says undermines.
struct AwardSheet: View {
    let award: AwardOutcome

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: LumoSpace.regular) {
            Spacer()
            VectorBuddy(mood: award.total > 0 ? .delighted : .calm)

            Text(award.feedback.headline)
                .font(.lumoTitle)
                .foregroundStyle(Color.lumoText)
                .multilineTextAlignment(.center)

            Text(award.feedback.detail)
                .font(.lumoBody)
                .foregroundStyle(Color.lumoHaze)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if award.total > 0 {
                VStack(spacing: LumoSpace.hair) {
                    Text("+\(award.total)")
                        .font(.lumoCoin)
                        .foregroundStyle(Color.lumoFlare)
                        .accessibilityIdentifier("award.total")
                    // Named separately so the unexpected ones read as unexpected. An unannounced
                    // bonus folded into the total is just a bigger number.
                    if award.comebackBonus > 0 {
                        Text("includes \(award.comebackBonus) for coming back")
                            .lumoSecondary()
                    }
                    if award.surpriseBonus > 0 {
                        Text("and \(award.surpriseBonus) unexpected")
                            .lumoSecondary()
                    }
                }
            }

            Spacer()
            PrimaryButton("Nice", isBusy: false) { dismiss() }
                .accessibilityIdentifier("award.dismiss")
        }
        .padding(LumoSpace.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .lumoBackground()
    }
}
