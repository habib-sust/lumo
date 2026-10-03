import LumoCore
import LumoShieldKit
import SwiftUI

/// The home screen: a vertical hearth, not a card dashboard.
///
/// The layout IS the metaphor. Buddy centre, in a pool of light whose reach is the balance. Locked
/// apps sit at the bottom edge, dim, **outside** the light — so "you cannot reach these yet" is
/// stated by position rather than by a padlock icon and a sentence. Buying a window moves an app
/// into the light and the light recedes in real time as the window burns down.
///
/// Everything else on this screen is deliberately quiet. The boldness is spent once.
struct HearthView: View {

    @Environment(AuthorizationService.self) private var authorization
    @Environment(\.scenePhase) private var scenePhase

    @Environment(HabitService.self) private var habits

    @State private var model = HearthModel()
    @State private var route: Route?

    private enum Route: Identifiable, Hashable {
        case settings
        case spend(BucketID)
        case habits
        case running
        case award

        var id: String {
            switch self {
            case .settings: "settings"
            case let .spend(bucket): "spend-\(bucket.slot)"
            case .habits: "habits"
            case .running: "running"
            case .award: "award"
            }
        }
    }

    var body: some View {
        ZStack {
            Color.lumoInk.ignoresSafeArea()
            LightRadius(warmth: model.snapshot.warmth, surge: model.surge)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    header
                    VStack(spacing: 20) {
                        VectorBuddy(mood: model.snapshot.mood)
                            .padding(.top, 12)
                        balance
                        earnRow
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(Color.lumoSoot, in: RoundedRectangle(cornerRadius: 32))
                    .overlay {
                        RoundedRectangle(cornerRadius: 32)
                            .strokeBorder(Color.lumoHaze.opacity(0.16), lineWidth: 1)
                    }
                    openRow
                    VStack(alignment: .leading, spacing: 16) {
                        LumoSectionHeading(
                            title: "Your apps",
                            subtitle: "A little intention before screen time."
                        )
                        lockedRow
                    }
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, LumoSpace.margin)
                .padding(.vertical, LumoSpace.loose)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            habits.load()
            model.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            habits.load()
            model.refresh()
        }
        // Sleeps until the soonest window is due, rather than polling.
        //
        // The countdown text redraws itself via `TimelineView` further down, scoped to the label —
        // if the tick lived up here as view state, every second would repaint a full-screen
        // gradient to move one digit. Cancelled and restarted automatically when the expiry
        // changes, and costs nothing at all when nothing is open.
        .task(id: model.snapshot.nextExpiry) {
            guard let expiry = model.snapshot.nextExpiry else { return }
            let remaining = expiry.timeIntervalSinceNow
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            guard !Task.isCancelled else { return }
            // The reconciler is the authority on whether the window actually closed — this view
            // only knows what time it is, and the monitor extension may have got there first.
            LumoStack.reconcileNow(.app)
            model.refresh()
        }
        .sheet(item: $route) { route in
            switch route {
            case .settings:
                SettingsView()
            case let .spend(bucket):
                SpendSheet(bucket: bucket, snapshot: model.snapshot) {
                    model.flash()
                    model.refresh()
                }
            case .habits:
                HabitsView()
            case .running:
                RunningTimerView()
            case .award:
                if let award = habits.lastAward {
                    AwardSheet(award: award)
                } else {
                    // Only reachable if the award was cleared between routing and presenting.
                    // Showing nothing beats showing a zero the user did not earn.
                    Color.lumoInk
                }
            }
        }
        // The award lands after a sheet dismisses, so it is routed on change rather than presented
        // from inside the sheet that produced it — stacking a second sheet on a dismissing one is
        // how the self-dismissing-sheet bug happened in the first place.
        .onChange(of: habits.lastAward) { _, award in
            guard award != nil else { return }
            model.flash()
            model.refresh()
            route = .award
        }
        .onChange(of: route) { _, value in
            if value == nil { habits.clearLastAward() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lumo")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.lumoText)
                    Text("Make room for what matters.")
                        .font(.subheadline)
                        .foregroundStyle(Color.lumoHaze)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button { route = .settings } label: {
                    Image(systemName: "gearshape")
                        .font(.lumoHeadline)
                        .foregroundStyle(Color.lumoText)
                        .frame(width: 48, height: 48)
                        .background(Color.lumoSoot, in: Circle())
                }
                .accessibilityIdentifier("home.settings")
                .accessibilityLabel("Settings")
            }
            if let guidance = authorization.guidance {
                Label(guidance.title, systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(Color.lumoEmber)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Balance

    private var balance: some View {
        VStack(spacing: LumoSpace.tight) {
            Text("Available coins")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.lumoHaze)
            Text("\(model.snapshot.wallet.total)")
                .font(.lumoCoin)
                .foregroundStyle(Color.lumoText)
            Text(balanceCaption)
                .lumoSecondary()
                .multilineTextAlignment(.center)
        }
        .padding(.top, LumoSpace.snug)
        // Combined so VoiceOver reads the number together with what it means, rather than
        // announcing a bare "120". The identifier goes on the combined element and NOT on the inner
        // Text — putting it on both makes two elements match the query, and the test fails with
        // "multiple matching elements" rather than anything that names the real problem.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.balance")
    }

    /// Competence feedback, not just a number going up.
    ///
    /// Pairing every award with informational feedback is one of the few mitigations with a
    /// positive effect size (d ≈ +0.31 to +0.36) against overjustification, whose own effect is
    /// d ≈ −0.36. A bare counter is the version the literature says backfires.
    private var balanceCaption: String {
        let wallet = model.snapshot.wallet
        if wallet.total == 0 {
            return "Nothing's lit yet. Do something you meant to do."
        }
        if wallet.earned == 0 {
            return "\(wallet.granted) from this week's allowance."
        }
        if wallet.granted == 0 {
            return "All \(wallet.earned) of these you earned."
        }
        return "\(wallet.earned) earned, \(wallet.granted) from this week's allowance."
    }

    /// The route to earning, and the running session if there is one.
    ///
    /// On the hearth rather than behind a tab, because a locked app with no visible way to earn is
    /// the screen that makes an app feel like a punishment.
    @ViewBuilder
    private var earnRow: some View {
        if let timer = habits.timer, let habit = habits.runningHabit {
            Button {
                route = .running
            } label: {
                HStack(spacing: LumoSpace.tight) {
                    Image(systemName: timer.isPaused ? "pause.circle.fill" : "timer")
                    Text(timer.isPaused ? "\(habit.name) — paused" : habit.name)
                }
                .font(.lumoCallout)
                .foregroundStyle(Color.lumoFlare)
                .padding(.vertical, LumoSpace.tight)
                .padding(.horizontal, LumoSpace.regular)
                .background(Color.lumoSoot)
                .clipShape(Capsule())
            }
            .accessibilityIdentifier("home.running")
            .padding(.top, LumoSpace.regular)
        } else {
            Button {
                route = .habits
            } label: {
                Label("Earn coins", systemImage: "plus.circle.fill")
                    .font(.lumoCallout)
                    .foregroundStyle(Color.lumoOnAccent)
                    .padding(.vertical, LumoSpace.tight)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 32)
                    .background(Color.lumoAccentFill)
                    .overlay { Capsule().strokeBorder(Color.lumoFlare, lineWidth: 1) }
                    .clipShape(Capsule())
            }
            .accessibilityIdentifier("home.earn")
            .padding(.top, LumoSpace.regular)
        }
    }

    // MARK: - Apps

    @ViewBuilder
    private var openRow: some View {
        if !model.snapshot.open.isEmpty {
            VStack(spacing: LumoSpace.tight) {
                LumoSectionHeading(title: "Open now", subtitle: "Enjoy your time. We'll handle the boundary.")
                ForEach(model.snapshot.open, id: \.bucket.id) { entry in
                    HStack(spacing: LumoSpace.snug) {
                        BucketLabel(bucket: entry.bucket)
                            .frame(width: 34, height: 34)
                        // Never interpolated with the app's name — that name is unreadable in this
                        // process by design. The system label above stands beside our text.
                        //
                        // TimelineView keeps the per-second invalidation inside this label instead
                        // of the whole hearth.
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(Countdown.phrase(until: entry.endsAt, now: context.date))
                                .font(.lumoTimer)
                                .foregroundStyle(Color.lumoFlare)
                        }
                        Spacer()
                    }
                    .lumoSurface(radius: LumoRadius.tile)
                }
            }
            .padding(.bottom, LumoSpace.regular)
        }
    }

    @ViewBuilder
    private var lockedRow: some View {
        if model.snapshot.locked.isEmpty {
            VStack(spacing: 16) {
                LumoEmptyState(
                    symbol: "apps.iphone",
                    title: "Choose your boundaries",
                    detail: "Choose the apps you'd like to spend less time in. Essential apps always stay available."
                )
                Button("Choose apps") { route = .settings }
                    .font(.lumoHeadline)
                    .foregroundStyle(Color.lumoFlare)
                    .frame(minHeight: 44)
            }
            .lumoSurface()
        } else {
            VStack(spacing: LumoSpace.tight) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: LumoSpace.snug) {
                        ForEach(model.snapshot.locked, id: \.id) { bucket in
                            Button {
                                route = .spend(bucket.id)
                            } label: {
                                BucketLabel(bucket: bucket)
                                    .frame(width: 52, height: 52)
                                    // Desaturate locked apps without fading their identifying icons.
                                    .saturation(0.25)
                            }
                            .accessibilityIdentifier("home.locked.\(bucket.id.slot)")
                            .accessibilityLabel("Locked app. Spend coins to open it.")
                        }
                    }
                    .padding(.horizontal, 2)
                }
                Text(lockedCaption)
                    .lumoDisclosure()
            }
        }
    }

    private var lockedCaption: String {
        if model.snapshot.calibration.isReady {
            return "Tap one to spend coins on it."
        }
        let days = model.snapshot.calibration.daysRemaining
        // Honest about the calibration window rather than silently pricing off a guess. The user is
        // told prices will move, before they move.
        return days == 1
            ? "Tap one to spend coins. Prices settle after one more day of watching."
            : "Tap one to spend coins. Prices settle after \(days) more days of watching."
    }
}

/// Countdown phrasing.
///
/// **Deliberately approximate.** iOS floors a `DeviceActivitySchedule` at 15 minutes and schedule
/// reliability degrades past ~45, so a window does not end at a precise second and promising one
/// would be a lie the user catches. "About 12 minutes left" is both true and calmer than a ticking
/// 11:59 — and the competitors that imply precision eat the reviews for it.
enum Countdown {
    static func phrase(until end: Date, now: Date) -> String {
        let remaining = end.timeIntervalSince(now)
        guard remaining > 0 else { return "Closing" }
        let minutes = Int(remaining / 60)
        if minutes < 1 { return "Less than a minute" }
        if minutes == 1 { return "About a minute left" }
        return "About \(minutes) minutes left"
    }
}

#Preview("Home") {
    HearthView()
        .environment(AuthorizationService())
        .environment(HabitService())
}
