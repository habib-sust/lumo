# Lumo — Build Plan

**Tagline: "Light comes first."** (Not "Earn Your Scroll" — see Naming below.)

> **Companion document:** the full architecture and implementation specification —
> 74 dependency-ordered tasks, 7 sequence diagrams, the cross-process state machine, the
> concurrency model, and the complete test matrix — is at
> `~/.claude/plans/i-want-to-build-enchanted-mochi-agent-abf310c72be6dd768.md`.
> Every Swift API claim in it was typechecked against the shipped iOS 26.5 SDK. **On platform
> facts, that document now supersedes this one** where they differ; the corrections are
> summarised below.

## Context

`/Users/habib/Github/iOS/Lumo` is a stock Xcode 26.5 SwiftData template: `LumoApp.swift`,
`ContentView.swift`, `Item.swift`, an empty asset catalog, three empty test stubs, no
entitlements, no dependencies, no `.gitignore`. One commit plus an uncommitted tweak setting the
app target to iOS 18.0. Toolchain Xcode 26.5 / Swift 6.3.2. All three template files get deleted.

The goal is an app in the mould of **Unrot: Earn Your Screen Time** (4.7★, 57k ratings): real-life
habits earn coins, coins buy timed unlock windows for apps the user chose to shield. Two deep
research passes — one on Apple's Screen Time API family from primary sources, one on the
behavioural-science and competitive literature — changed the plan materially. Both are worth
reading before implementation; the science dossier is ~26,000 words and lives at
`~/.claude/plans/i-want-to-build-enchanted-mochi-agent-aa9d224a6f3935859.md`. **Phase 0 copies both
into `docs/research/` in-repo** so the evidence ships with the code.

Two findings frame everything below:

**The mechanic is commoditized.** A single App Store search surfaced 40+ direct competitors, most
launched in the last 12 months, plus a whole "walk to unlock" sub-niche. Three credible players
already run earn-to-unlock economies (Unrot, Clearspace, Jomo). There is no first-mover advantage
left. The remaining whitespace is a genuinely *fungible* wallet priced off each user's own
baseline — nobody does that — plus the things every competitor does badly: price, trust,
reliability.

**The naive coin loop is the design the reward literature says backfires.** Expected, tangible,
completion-contingent rewards undermine intrinsic motivation at **d ≈ −0.36**; gamification's
behavioural benefit against a plain tracker is **g ≈ 0.23** and goes null under trim-and-fill and
under high-rigor restriction. Comparable magnitude, opposite sign. And "it's only virtual points"
is not a defence — symbolic rewards undermined as much as concrete ones (d = −0.42 vs −0.44, n.s.).
So the economy below is deliberately *not* the obvious one.

### Decisions locked with the user

| Axis | Decision |
|---|---|
| Naming | **Keep "Lumo," new tagline.** "Earn Your Scroll" is the literal opening sentence of Unrot's App Store description — using it is a 4.1 Copycats risk, a trademark exposure, and an ASO trap. Also note **"Luma: Earn Screen Time"** shipped 2026-07-26, one letter away. |
| Scope | **Core loop only:** pick apps → shield → timed habit → coins → timed unlock that auto-re-locks. |
| Data | Local SwiftData + App Group. No account, no server. |
| Buddy | Vector/SwiftUI-native behind a protocol, so Rive/sprites can swap in later. |
| Habits v1 | **Timer habit only** — one generic engine the user names and durations. |
| Escape hatch | **Free unlock behind ~20s friction**, always available, logged. Never a hard wall. |
| Buddy tone | **Sleepy, never sick.** |
| Economy | **Hybrid: weekly house grant (decays on misses) + earned coins on top.** |
| Pricing | **Threshold ladder** — infer baseline usage from `DeviceActivityEvent` thresholds, personalize silently after 3 days. |
| Entitlement | Not yet requested. |

---

## P0 — Non-negotiable before anything else

**Submit the Family Controls Distribution entitlement request today.** No SLA; documented waits
run from one week to five months. It gates **TestFlight as well as App Store** — Apple DTS:
*"TestFlight uses a distribution provisioning profile, just like the App Store."* It must be filed
**separately for every bundle ID** (app + each extension = 4–5 requests) and only the **Account
Holder** can submit. Write a substantive justification naming bundle IDs, frameworks, exactly what
gets shielded, and the concrete user benefit — the one documented rejection was recovered by
resubmitting a more detailed application. The **Development** capability is self-serve and unblocks
device work immediately, so build against it while waiting.

**Protect essential apps — but the hard-coded allowlist is not implementable as first written.**
An Unrot reviewer: *"I am a type 1 diabetic and it would block my pump… I can die from that."* This
is the one failure mode in the project with a physical-harm path.

SDK verification found the mechanism doesn't exist: `ApplicationToken`s are opaque, and
`ShieldSettings.ActivityCategoryPolicy.all(except:)` takes **tokens**, not bundle identifiers. You
cannot recognise a CGM app to exempt it. `FamilyActivityData.installedApplications` (iOS 26.4+) does
expose `Application.bundleIdentifier` alongside `.token`, which would allow a genuine bundle-ID →
token map — **but Apple restricts it in production to the EU.** Verbatim: *"Customer installations of
your app can only use the class on devices located in the EU that are signed in with an Apple Account
with an EU country or region."* It also requires `approvedWithDataAccess` and a separate restricted
entitlement. So it cannot be the worldwide mechanism.

The design becomes three tiers:

1. **A mandatory user-authored essential-apps step, placed *before* the blocklist picker.** This is
   the primary mechanism worldwide, not a fallback.
2. **Auto-seed from hard-coded bundle IDs on iOS 26.4+ in the EU**, if the spike confirms it works.
3. **Permanent in-app honesty** about what iOS does not let us guarantee.

Enforced **inside the reconciler**, not only in the picker — so an essential token present in the
bucket table is never shielded regardless of how it got there. **Onboarding copy must not promise
automatic medical-app protection** unless the spike passes and the user is in the EU.

**Never trap the user.** Competitor reviews include *"Impossible to delete: the app hides the delete
button"* and *"one of the most dangerous applications I have ever installed."* Ship a permanent,
obvious **"Unlock everything and remove Lumo"** path that never requires a Screen Time passcode the
user may not have.

**Never block the tools a task needs.** A study session must not shield the calculator or Anki.

**The free tier carries the full earn→unlock loop.** Hard paywalls are the category's #1 killer —
recent 1★ rates: PushUp Time 39%, AppBlock 32%, Unrot 30%, Forest 29%, with reviewers
self-identifying as teenagers without money. Against that, ScreenZen is free and holds 4.86 across
46,632 ratings, and Finch is free/ad-free with cosmetic-only paid tiers, holding 4.95 across
735,553 ratings and 37% D7 retention on ~$30M ARR. Guideline 4.10 makes a hard paywall around
Screen Time functionality the most legally exposed configuration available.

**Coins are earned only — never purchasable, transferable, or redeemable.** Guideline 4.10 verbatim:
*"You may not monetize built-in capabilities… or Apple services and technologies, such as Apple
Music access, iCloud storage, or **Screen Time APIs**."* No coin IAP, no rewarded ads, no
subscription tier granting more or cheaper unlock time. Monetize cosmetics, insights, and coin
sinks — which is also the most-requested Unrot feature (*"I just wish I could spend my coins on
customization"*) and, per Finch, the bigger business. State the earned-only rule in-app and in App
Review notes.

**Lumo must work with Screen Time access declined** (Guideline 5.1.2(i)). Habits, timers, and the
buddy all function; shielding is an enhancement, not a wall. A launch flow that dead-ends on the
authorization screen is a plausible rejection.

---

## Platform architecture

### Hard limits to design against

| Limit | Value |
|---|---|
| Shielded application tokens | **50** — silent, total failure at 51. Validate and cap in the picker. |
| Named `ManagedSettingsStore`s | 50 |
| Concurrent DeviceActivity activities | 20 (app + all extensions combined) |
| `DeviceActivityMonitor` memory | **6 MB** high-watermark — process dies instantly |
| `DeviceActivitySchedule` interval | **min 15 minutes** (`intervalTooShort`), max 1 week |
| Schedule reliability | Degrades past ~45 min; chain watchdogs |
| Simulator | **Family Controls does not work at all.** Device-only, needs passcode + iCloud. |

### Targets

```
Lumo                       (app)         SwiftUI + SwiftData + design system
LumoCore                   (SPM, static) Foundation ONLY — portable, macOS-testable
LumoShieldKit              (SPM, static) iOS adapters over Screen Time frameworks
LumoMonitorExtension       DeviceActivityMonitor
LumoShieldConfigExtension  ShieldConfigurationDataSource  (+ UIKit)
LumoShieldActionExtension  ShieldActionDelegate
```

**The `LumoCore` / `LumoShieldKit` split is the single most valuable structural decision here.**
`LumoCore` holds the reconciler, the spend journal, the wallet, bucket partitioning, and the pricing
math — with *zero* Screen Time frameworks, so it compiles and tests **on macOS**. That converts "the
shield path can never be integration-tested" into a ~15-second CI run covering ~90% of the dangerous
logic, including simulated mid-spend process death. Both packages static, not dynamic, to keep the
monitor extension's link graph and launch cost minimal.

`LumoReportExtension` is **deferred** — its sandbox blocks network *and* prevents data leaving the
extension, so it can only render opaque views. Usage telemetry comes from `DeviceActivityEvent`
thresholds instead, the sanctioned channel.

All targets get the Family Controls capability and App Group `group.com.habib.Lumo`. New targets
require real `project.pbxproj` surgery; source files do not, because the project uses
`PBXFileSystemSynchronizedRootGroup` (objectVersion 77).

**Extension import discipline is a hard rule.** The three extensions may import only `Foundation`,
`DeviceActivity`, `ManagedSettings`, `ManagedSettingsUI`, `UserNotifications`, and `LumoShieldKit`.
No SwiftData, no SwiftUI, no analytics, no networking. A 6 MB overrun means the shield never
re-applies — silent total failure, invisible in metrics.

### Data plane

**Tier 1 — App Group `UserDefaults`.** The only cross-process state: active session, coin balance,
bucket definitions with tokens, pending unlock, schema version. Small Codable blobs.

**Tier 2 — SwiftData in the App Group container, main app only.**
`ModelConfiguration(groupContainer: .identifier(...))`. Habit definitions, session history, coin
ledger, streaks, baseline observations.

`UserDefaults` has no transactions and the coin-spend sequence spans three effects (debit →
unshield → start monitoring). Write an intent record first, perform the effects, then mark it
settled, so `reconcile()` can finish or roll back a half-applied transaction. Without this, an
extension killed mid-spend leaves coins gone and apps still locked.

Cross-process pings use Darwin notifications (`CFNotificationCenterGetDarwinNotifyCenter`, public
API, payload-free) — opportunistic only, never load-bearing. Cross-process KVO on `UserDefaults` is
unreliable.

### Store topology

Partition the selection into fixed **buckets** at setup, one named store each. Unlocking clears or
deactivates that bucket's store; re-locking restores it. Tokens never move between stores, which
structurally avoids the known stale-shield bug where a migrated token leaves the shield UI
rendering a dead block. On **iOS 26.5+** use `store.isActive` — atomic, no token churn. Below that,
`clearAllSettings()` and re-apply. Gate with `#available`.

Use `shield.applications`, never `application.blockedApplications` — a hard block removes the
shield, and the shield is the entire entry point for spending coins.

### Token rotation self-heal

Complaint #2 across every competitor is "it stopped blocking / blocked the wrong thing." The root
cause is **iOS unpredictably reissuing `ApplicationToken`s**, independently reported by the developers
of ScreenZen, Jomo *and* Opal. Apple DTS in July 2025: *"there's no code-level workaround, because
tokens are opaque by definition."*

**There is now.** iOS 26.5 added `ManagedSettingsStore.refresh(_ tokens: inout [ApplicationToken])`
(plus category and web-domain overloads) and a `TokenExpiryMessage` / `.tokensDidExpire` notification —
both verified in the SDK. So repair is automatic and event-driven above 26.5, and heuristic below it:
read-back integrity check on foreground, unknown-token detection in the config extension, a generic
shield instead of a crash, and a one-tap repair banner.

One caveat before relying on it: the mutation contract is undocumented. Whether `refresh` preserves
order, drops unrecoverable tokens (shortening the array), or touches non-expired elements all matter,
because a silent drop would corrupt the slot table. **Do not correlate by index until that's measured.**

Being honest in-app about known iOS limitations is cheap, differentiating, and true — every competitor
eats 1★ reviews for platform bugs they never explain.

### Buckets: one token each, capped at 40

A bucket is **exactly one token** — one app (or one category) per named store. Multi-app buckets
over-deliver: you pay for TikTok and get Instagram free, which pushes the effective price below the
user's baseline ratio, and that's precisely where **the contingency becomes a punisher** and suppresses
the habit the economy is meant to build. Cap at **40**, not 50, for headroom under both the 50-token
silent cliff and the 50-named-store limit. Slots are stable and tokens never migrate between stores,
which makes the stale-shield variant of the rotation bug structurally impossible.

Categories are the only route past the 40-app cap, so keep them — priced separately and
conservatively, capped at 8 — but prefer per-app selection in the picker.

### The unlock mechanism — layered, with wall clock primary

**Correction from SDK/forum verification: usage-metering cannot be the primary trigger.**
`eventDidReachThreshold` is reported still firing at **+0 seconds** on iOS 26.5.2 — with
`includesPastActivity: false` explicitly tested — and no Apple reply. Left primary, a user pays 45
coins and the window shuts instantly. So the layering inverts from my earlier recommendation:

```
Layer 0  App Group state — source of truth
Layer 1  DeviceActivitySchedule wall clock  → intervalDidEnd → re-shield     [PRIMARY]
Layer 2  DeviceActivityEvent usage threshold → advisory early close,
         honoured only after a ~120 s sanity floor                          [ADVISORY]
Layer 3  Local-notification watchdog at windowEnd                           [INDEPENDENT]
Layer 4  App foreground: SYNCHRONOUS reconcile() before any UI or DB work
Layer 5  Shield extensions reconcile on every invocation (config = read-only)
```

Three structural points behind this:

- **Layer 3 must not be more DeviceActivity.** Chained watchdog schedules at +15/+30/+44m — my
  earlier suggestion — burn three activities per session against the 20 cap, sit exactly on the
  `intervalTooShort` floor, and *share the failure mode of the thing they watch*. A watchdog that
  dies with its subject is not a watchdog. A `UNCalendarNotificationTrigger` is genuinely
  independent, and multiple threshold events inside one activity cost nothing extra.
- **Callbacks are triggers, never data.** Nothing branches on which activity or event arrived; every
  reconcile recomputes from persisted state plus `now`. That makes spurious `intervalDidEnd`,
  phantom thresholds, and duplicate deliveries harmless by construction.
- Layer 4 must not `await` before reconciling — an async gap lets the user background Lumo
  mid-suspension and leaves shields partially applied.

Consequence for the product: **sub-15-minute "quick peek" tiers are off by default**, and the
"a pocketed phone doesn't burn your coins" line cannot go in marketing until the spike returns.

**Spend ordering is the highest-severity correctness decision in the project.** My earlier
`debit → unshield → arm monitoring` is wrong: it opens a crash window where apps are unshielded with
**no armed timer** — unbounded free access, silent and permanent. Invert it to
**`debit → arm monitoring → unshield`**. The unshield goes last because by then the OS already holds
a timer that guarantees re-locking, which makes "unlocked forever" unreachable. Every crash state is
then either a clean rollback or already OS-protected.

`ShieldReconciler.reconcile()` is synchronous, idempotent, and called from all four processes.
`startMonitoring` on an existing `DeviceActivityName` fires a spurious `intervalDidEnd`, so use a
fresh UUID name per session and garbage-collect against the 20-activity cap. **Never
`BGTaskScheduler`** for the timer — no guarantee, dead in Low Power Mode, dead when force-quit,
arguably a 2.5.4 concern.

Design the copy around the honest limit: not "re-locks in exactly 15:00" but "your window ends
around 2:45."

### Shield UX

**Correction: iOS 26.5 added an official way back into the app.**
`ShieldActionResponse.openParentalControlsApp` exists — verified in the SDK, `@available(iOS 26.5, *)`.
My earlier "you cannot open Lumo from the shield" holds for **iOS 18.0–26.4** but is no longer true
on 26.5+. It carries no associated value, so no context and no deep link, and it's a peer enum case
rather than a modifier — you cannot both `.close` the shielded app and open Lumo. The App Group
handoff stays mandatory: write the intent *before* returning the response.

Three redemption paths, by floor:

- **iOS 26.5+:** `.openParentalControlsApp` — pending device spike on dismissal semantics and whether
  it works under `.individual` at all (both undocumented).
- **iOS 26.4+:** secondary button → `secondaryButtonSubmenuItems` → transaction settles inside
  `LumoShieldActionExtension`, no app round-trip.
- **iOS 18.0–26.3:** secondary button → write pending-unlock, post a local notification → `.close` →
  user taps banner → Lumo opens to the spend sheet.

**The submenu contract is positional and needs care.** Items are `[String]`, max three, and the
response arrives as `.firstSecondarySubmenuItemPressed` / `.second…` / `.third…` — an *index*, with no
identifier round-trip. Two extensions therefore have to agree on ordering, and mis-ordering silently
sells the wrong tier. Solve it by making the tier ladder a **pure deterministic function** of (bucket,
wallet, policy), recomputed and re-validated in the action extension rather than handed across as
written state. Two further documented details: the system **adds its own Cancel button** (don't spend
a slot on one), and supplying a submenu **suppresses `.secondaryButtonPressed`**, so the delegate must
implement both paths.

The shield is a fixed system layout — blurred background, one icon, title, subtitle, two buttons,
text and colour only. **No custom SwiftUI.** So the friction screen lives in Lumo, not on the shield.
Note `import UIKit` is required in the config extension (`ShieldConfiguration` takes `UIColor` /
`UIImage` / `UIBlurEffect.Style`, and the project's member-import-visibility setting means it doesn't
arrive transitively) — which in turn means the shared framework must never expose UIKit types, or the
6 MB monitor extension inherits a UIKit link.

Redemption still cannot be one tap: there is no way to launch a target app from an `ApplicationToken`.
Design the flow as unshield-then-user-navigates, and set that expectation in copy. Competitors imply
one tap and eat the reviews.

### Authorization

`.individual`, requested on every launch (status changes externally) and re-checked on
`scenePhase == .active`. Handle every `FamilyControlsError` with a specific recovery, and no path may
dead-end — every screen needs a "continue without locking" exit (Guideline 5.1.2(i)).

**One subtle bug class to ban outright: never write `status == .approved`.** iOS 26.4 added a fourth
case, `AuthorizationStatus.approvedWithDataAccess` (verified in the SDK). An equality check against
`.approved` returns `false` for a user who granted *more* access than you asked for — silently
disabling shielding for every 26.4+ user on that path. Always `switch` with `@unknown default`. Same
applies to `ShieldAction`, `ShieldActionResponse`, and `FamilyControlsError`: all are
library-evolution enums, all gained cases recently. Make both a merge-blocking CI grep.

Accept the consequence honestly: on `.individual`, Apple *explicitly removes* the restrictions that
would prevent app deletion. **The user can always delete Lumo and every shield goes with it.** No
API prevents this, and per the friction literature that's arguably the correct design anyway. Make
deletion feel like a loss — visible banked coins, streak history, a buddy. Never `denyAppRemoval`
(global, user-hostile, undocumented under `.individual`), never MDM (5.5), never private API, and
never market Lumo as unbypassable.

---

## The economy

This is where Lumo differentiates, and where the science does the most work. Internally we say
**"response deprivation,"** not "Premack" — it forces the right question.

### Structure: house grant + earned, from ACTIVE REWARD

Chokshi et al. (2018) is the only loss-framed design whose effect **survived after incentives
stopped** (+1,154 steps at 8-week follow-up): a weekly house-funded virtual account with deductions
for misses, plus goals ramping **+15%/week from each user's own measured baseline**. Fixed-goal
designs lost their effect at follow-up.

- A **weekly coin allowance granted by the house**, which decays for missed days.
- **Coins earned from habits on top**, and earned coins are **never** clawed back.
- Misses deduct **only from the granted portion**. This distinction is load-bearing: house money is
  a designed, anticipated, reference-point-resetting mechanic, whereas taking back what a user
  earned reads as betrayal and specifically harms your most engaged users. Asking users to risk
  something already theirs collapses acceptance from 90% to 13.7%.
- Targets ramp **+15%/week from the user's own baseline**, which is simultaneously the loss-framing
  spec, the response-deprivation spec, and Behavioral Activation's graded-task component. Three
  literatures converge on one mechanic.

The grant also satisfies "never trap the user" — there is always a floor.

### Pricing: the threshold ladder

The disequilibrium model says a contingency only reinforces when the required ratio sits **above**
the user's baseline ratio. Two failure modes, both fatal and both invisible without calibration:
if unlock time exceeds baseline scroll time there is no deprivation and you've built nothing; if
the rate falls *below* the baseline ratio **the contingency becomes a punisher and suppresses the
habit.** A too-generous price is worse than no app.

Since per-app minutes are unreadable, infer the baseline: register `DeviceActivityEvent` thresholds
at 15/30/60/120 min on the target apps and derive a usage bucket from which fire. Run global
default prices for the first 3 days, then personalize silently.

- Guarantee **multiple earn→spend cycles per day** (heuristic: reinforcer earned ~4× per session).
  Saving three days for one unlock will fail.
- Watch **ratio strain** — it is the #1 churn risk. A requirement ~6× baseline causes the behaviour
  to stop just short of the reward.
- Keep rewards **small**. In a 61,293-person megastudy, $0.09 beat $1.75; magnitude saturates
  immediately.

### Overjustification mitigations — not optional polish

These are what make the mechanic defensible at all, given the net effect is plausibly near zero
without them.

| Mitigation | Evidence |
|---|---|
| Pair every award with **informational competence feedback**, not just a number rising | Positive feedback d = +0.31 to +0.36 |
| **Performance/standard-contingent**, never engagement-contingent — reward completing a real standard, never mere participation | −0.28 vs −0.40, the most harmful cell |
| **Unexpected bonus sprinkles** | Unexpected tangible rewards: d = 0.01, no undermining |
| **Maximum autonomy support** — user authors the habits, sets prices, picks blocked apps | SDT core. Note no gamification element supported autonomy in Sailer et al.; it has to come from information architecture |
| **Don't attach coins to activities the user already loves** — reserve the economy for genuine chores | Undermining needs pre-existing intrinsic motivation to destroy |
| Keep an explicit **un-monetized "for its own sake" habit list** | Prevents crowding out existing drives |

Never promise "and then you won't need the app" — contingency management decays to d = −0.09 at 6
months. Be honest that Lumo is an ongoing contingency.

### Recovery before streaks

Three literatures converge: the **#1 intervention of 53 tested on 61,293 people** was a bonus for
returning after a missed session; one missed day costs <0.5 automaticity points and recovers
quickly; and a harsh reset triggers the what-the-hell effect — a binge, not a comeback.

**Streaks pause, never reset.** A comeback bonus fires on the next completed session. Escalating
coin tiers carry a documented "re-earn your tier in 3 clean days" rule. A permanent "restore your
old streak" path exists for lapsed users. **And forgiveness is free** — Duolingo charges gems for
streak freezes, and chronically ill and disabled users defend those items as accessibility
features, which means monetizing them taxes exactly the people who need them most.

Ship **endowed progress**: start users with 2 of 12 stamps filled. Expect a post-reward slump.

### Buddy

Finch's rule — *"your bird never dies, streaks never punish you, and missing a day costs you
nothing"* — accompanies the best retention in the dossier. The entire category chose punishment
instead: Unrot's buddy loses energy when you scroll, Brainrot's avatar decays, Forest kills your
tree. Habitica proves punishment churns users *and* fails to motivate.

**A companion you help, never one you hurt.** Give it a **narrative** — game fiction is one of only
two gamification elements with real moderator evidence (behavioural g = .49 with vs .02 without).
Cosmetic coin sinks are the most-requested competitor feature and the safest monetization surface
under 4.10.

### Friction

Grüning et al. (2023, *PNAS*): 36% dismissal, 37% fewer open attempts, 57% combined reduction over
6 weeks. The preregistered component decomposition matters — **the dismiss option was strongest,
the time delay also worked, and the deliberation message did nothing.** So the emergency-unlock
screen is a delay plus a prominent "actually, never mind" button, and **no motivational text.** Plan
for decay: dismissal fell 43% → 33% over three weeks.

### Pair blocking with breaks, and segment by self-control

Mark, Czerwinski & Iqbal (CHI '18): a week of blocked distractions raised focus **but** produced
lower enjoyment, less flow, **higher workload for users already high in self-control**, and longer
stretches without physical breaks with consequently higher stress. Benefits concentrated in users
*less* in control of their work. So: ship enforced break prompts, ask about baseline self-control at
onboarding and dial strictness accordingly, and **track enjoyment, not just compliance** —
throughput metrics will not reveal this harm.

Protect users from themselves: 55% of clients defaulted on self-designed commitment contracts and
lost money; about half of takers accepted contracts pointing the wrong direction. Enforce maximum
block severity, mandatory emergency unlocks, and a cooling-off delay before any strictness increase
takes effect.

### Do not build

Streak resets to zero · a pet that decays or sickens · shaming copy · engagement-contingent coins ·
coins on activities the user already loves · over-generous exchange rates · large rewards ·
real-money stakes · irreversible modes without a safety valve · a hard paywall on core
functionality · motivational text on the shield · **a standalone leaderboard** (intrinsic
motivation, satisfaction and empowerment all declined significantly over 16 weeks, with a
significant negative indirect effect on performance) · a gamification layer with no narrative ·
clawing back earned coins or streaks · more mechanics for their own sake (element count predicts
nothing: b = .01, p = .91).

---

## Design direction — "Ember"

The name is the concept: *Lumo* is light. The arc is night → dawn, and one value — light earned —
drives the interface.

| Token | Hex | Role |
|---|---|---|
| `ink` | `#14121C` | Base. Near-black shifted warm-violet — cozy, not clinical. |
| `soot` | `#241F2E` | Raised surfaces. |
| `ember` | `#FF7A3D` | Primary. Coins, energy, light. |
| `flare` | `#FFC44D` | Coin fill, the hot centre of the glow. |
| `moss` | `#6FD3A8` | *Only* for "you did the thing" confirmation. |
| `haze` | `#A79FB8` | Secondary text, dim/locked states. |

Dark-first, because glow needs somewhere to fall off. **Type:** Bricolage Grotesque (bundled
variable font) for headlines and the coin counter only; **SF Pro Rounded** for UI/body, which is
system-supplied so Dynamic Type and accessibility come free and Rounded is a deliberate warmth
choice; **SF Mono** tabular for timer and ledger.

**Signature: The Light Radius.** Coin balance drives a radial gradient's radius, global saturation,
and the buddy's animation energy. Home is a vertical *hearth*, not a card dashboard: buddy centre in
a pool of light, shielded apps at the bottom edge **outside the light**, dim. Buying an unlock surges
the radius and illuminates those icons, then the light recedes in real time as the window expires.
Balance HUD, progress bar, countdown, and emotional signal in one object with no chrome.

Because tokens are opaque, that app row must be built from `Label(token)` — the system renders the
real icon and name out-of-process. We can never read the name as a string, so "TikTok — 25 coins" is
composed as `Label(token)` beside our own price text, never interpolated.

Everything else stays quiet: flat surfaces, no other gradients, no glassmorphism. Spend the boldness
once. **Motion:** one orchestrated moment — habit completion sends motes into the buddy, the radius
springs outward, the buddy bounces. Elsewhere an idle breathing loop. Reduced-motion falls back to
opacity crossfades and a static radius.

**Voice:** second person, plain verbs, never shaming. "Locked," not "Blocked." Empty state:
"Nothing's lit yet. Pick something to do." Never "You've wasted 4h today" — shaming copy is directly
cited in competitor 1–2★ reviews as the reason for uninstalling.

---

## Build phases

74 dependency-ordered tasks with acceptance criteria are in the architecture document (§8). Summary:

| Phase | Goal | Tasks | Demonstrable at exit |
|---|---|---|---|
| **0** Unblock & scaffold | Entitlement clock running; 4 targets build and install on device; CI can already fail a bad import | T-001→010 | App launches to a placeholder with three extensions installed |
| **1** `LumoCore` first | The entire risky logic layer, fully tested, on macOS, no device involved | T-020→038 | ~120 macOS tests green in <10s, including simulated mid-spend process death |
| **2** Auth & picker | User grants access, protects essential apps, picks a blocklist, sees real shields | T-040→047 | On device: pick apps, watch them shield, tap one, see the Lumo shield |
| **3** Shield & unlock | The full loop — spend coins, get a window, watch it re-lock itself | T-050→062 | The product's core promise, end to end, on a physical phone |
| **4** Habits & economy | Coins come from somewhere real, priced off the user's own baseline; the hearth exists | T-070→085 | Do the dishes, earn coins, unlock TikTok, watch the light recede |
| **5** Hardening | Known failure modes known, instrumented, and explained to the user | T-090→096 | TestFlight-ready build |

**Phase 0 detail** (the parts that are easy to forget): file the entitlement requests **first, today**;
enable the Development capability; add `.gitignore`; fix the test targets' deployment target (currently
26.5 against an 18.0 app — they won't run on an iOS 18 simulator); delete `Lumo/ContentView.swift` and
`Lumo/Item.swift` and rewrite `Lumo/LumoApp.swift`; copy all three research documents into
`docs/research/` so the evidence ships with the code.

Two build-setting requirements that are mandatory rather than stylistic:

- **Move to Swift 6 language mode now.** Three template files exist; migration cost is ~zero today and
  grows superlinearly. The only real blocker — **nothing** in `ManagedSettings` or `DeviceActivity` is
  `Sendable` (verified: zero conformances in either interface) — is solved by one small shim file.
- **`SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated` on all three extension targets.** The app target's
  `MainActor` default makes `DeviceActivityMonitor` **impossible to subclass** under Swift 6 — the
  overrides are non-isolated, so a MainActor-isolated subclass won't compile. Also:
  `UserDefaults`' `Sendable` conformance is explicitly unavailable, so the App Group handle must be a
  documented `nonisolated(unsafe)` global.

**Riskiest task in the project is T-008** (pbxproj surgery for three extension targets).
`objectVersion 77` + `PBXFileSystemSynchronizedRootGroup` is young and thinly documented, and a
malformed pbxproj is a corrupt project. Create the targets through Xcode's UI (which writes valid
77-format objects), hand-edit only the settings afterwards, commit the pbxproj alone, and verify with
`xcodebuild -list` and `-showBuildSettings` per target before adding any source.

**Scheduling reality:** all six phases can complete against the Development capability on a personal
device. Plan for Phase 5 to finish *before* the Distribution entitlement arrives, and treat that wait
as the critical path it is.

---

## Testing scope

The governing fact: **Family Controls does not work in the Simulator at all.** So the strategy isn't
"test the shield path in CI" — that's impossible. It's to push as much correctness as possible *below*
the Screen Time frameworks, into `LumoCore`, where it runs on macOS in seconds.

**Tier 1 — unit tests on macOS (`swift test`, ~15s, merge-blocking, coverage gated ≥85% on `LumoCore`).**
This is where testing actually happens:

- `reconcile()` expiry against an injected `now`; idempotence (`reconcile(); reconcile()` produces
  identical state and zero second-pass writes)
- **Every row of the spend-crash table** — process death at each of the three commit points, proving
  each state is either a clean rollback or already OS-protected
- The **grant-vs-earned invariant** as a property test: `earned` is monotonic under *any* sequence of
  misses; no code path decrements it except a user-initiated spend
- Bucket partitioning at 39 / 40 / 41 tokens, and slot stability across add-remove-add
- The essential-apps deny-set, including "an essential token present in the bucket table is never
  shielded"
- Baseline-ratio pricing at **both** admissible-band boundaries, including the punisher boundary
- Weekly grant issue / rollover / expiry across a simulated 3-week clock
- Journal ingestion idempotence and the ledger-wins-on-divergence rule
- Codable round-trips, including decode-from-`{}` for every field

**Tier 2 — merge-blocking greps.** Three failure modes that are catastrophic, invisible in review, and
trivially detectable: `blockedApplications` (removes the shield, destroying the coin-spend entry
point), `== .approved` (silently breaks shielding for 26.4+ users), and `async` anywhere in the
packages (breaks the synchronous Layer 4 guarantee). Plus import-allowlist and layering lints, proven
to fail on a deliberately planted violation.

**Tier 3 — device-only, never in CI.** `AuthorizationCenter`, `ManagedSettingsStore`,
`DeviceActivityCenter`, `FamilyActivityPicker`, and all three extensions. Signed off in
`docs/qa/device-matrix.md` keyed to a commit SHA, as a **release gate** rather than a merge gate:
cold launch, force-quit mid-window, reboot mid-window, airplane mode, Low Power Mode, clock change,
revoke-and-restore authorization, 41-token overflow, unknown token delivered to the shield, an
essential app confirmed never shielded, and a soak test across a reboot and a timezone change.

Extension code is testable *because the extensions contain no logic* — every override is a one-line
call into `LumoCore`. Enforce it: an extension source file over ~120 lines is a review flag. Beyond
that, `xcodebuild build -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`
catches isolation and availability errors with no hardware, and a link-graph gate protects the 6 MB
ceiling better than a size check does — the documented cause of overruns is linking something heavy,
not allocating too much. Budget 3 MB, alarm at 4.5. Add a resident-size self-report into a diagnostic
ring buffer: a Jetsam kill leaves no crash log a user would ever report, so that's the only field
telemetry available.

**Tier 4 — snapshot tests** for design-system primitives and the hearth, across three Dynamic Type
sizes × light/dark × reduce-motion.

**Five spikes, and what each one blocks:**

| Spike | Question | Blocks |
|---|---|---|
| **1** (P0) | Can bundle IDs be mapped to tokens — `Application(bundleIdentifier:).token`, and `FamilyActivityData` on 26.4+/EU? | Safety-allowlist onboarding **copy**. If it fails, the copy must not promise automatic medical-app protection. |
| **2a** | Does `intervalWillEndWarning` fire dependably at short leads? (No documented minimum — the "15-minute" figure is community lore, so it must be measured.) | Whether sub-15-minute tiers exist at all |
| **2b** | Does `.defer` after unshielding dismiss the shield in place, or force a relaunch from Home? | Whether redemption is one tap or three — changes the whole spend-flow copy |
| **3** | `.openParentalControlsApp` semantics under `.individual`; does the shield dismiss? | Whether the 26.5 path replaces the notification bridge |
| **4** | Does `refresh(_:)` preserve order / drop tokens / throw what? | Token-rotation repair. **Never correlate by index until answered.** |

**Instrument for harm, not just engagement.** Track forfeiture, failure, emergency-unlock and
self-reported enjoyment as first-class local metrics with hard thresholds. If >50% of users on the
strictest tier are failing their own contracts, the design is harming them regardless of what
compliance says. Interrupted people *compress* rather than lose time, so throughput metrics will never
reveal this — only stress and enjoyment measures will. And **don't judge retention on a two-week
pilot**: the effect troughs around week 4 for 2–6 weeks, then partially self-recovers by weeks 6–10.

**One citation-hygiene rule.** The dossier logged six published errors, non-existent papers, and
fabricated statistics circulating publicly. Check any science claim against its "Verification debts"
section before it reaches marketing or onboarding copy.

---

## Open decisions for you

Five things the architecture flagged as owner calls rather than engineering ones, each best decided
before the phase that depends on it:

1. **Is the honour-system build (habits, timer, buddy, economy, no shielding) a real release or an
   internal stopgap?** If real it needs its own onboarding and store copy — roughly two weeks nobody
   has scheduled. It's the hedge against the entitlement wait.
2. **Is the monetization model locked?** The ledger's entry kinds encode it, and adding a
   purchasable-coin path later is a schema migration *plus* a Guideline 4.10 argument.
3. **Do we raise the floor to iOS 26.5** to get automatic token repair? That trades a large install
   base for the single biggest reliability differentiator. My recommendation: no — keep 18.0 and make
   honest repair UX the differentiator instead.
4. **Are we willing to steer high-self-control users away from the strict tier?** Revenue-negative,
   evidence-positive.
5. **Confirm the name is genuinely locked** before the design-system task bundles a font and builds a
   palette around it.
