# Entitlements

## What Lumo needs

Two entitlements, on **all four** bundle IDs.

| Key | Value | Approval |
|---|---|---|
| `com.apple.developer.family-controls` | `true` | Development: **self-serve**. Distribution: **Apple review, per bundle ID** |
| `com.apple.security.application-groups` | `["group.com.habib.Lumo"]` | Self-serve |

The Family Controls key is the same string for both variants — what differs is which
provisioning profile Apple will issue for it. Development works today; Distribution
gates TestFlight *and* the App Store.

## Bundle IDs

| Target | Bundle ID | Entitlements file |
|---|---|---|
| Lumo (app) | `com.habib.Lumo` | `Lumo/Lumo.entitlements` |
| Monitor extension | `com.habib.Lumo.monitor` | created in T-008 |
| Shield config extension | `com.habib.Lumo.shieldconfig` | created in T-008 |
| Shield action extension | `com.habib.Lumo.shieldaction` | created in T-008 |

## Manual steps

**Portal, self-serve — do this first, it unblocks device testing:**

1. Identifiers → App Groups → register `group.com.habib.Lumo`.
2. For each of the four App IDs: enable **Family Controls** and **App Groups**, and
   select the group above.
3. In Xcode, set `CODE_SIGN_ENTITLEMENTS` per target (see below).

**Distribution requests — do this today, it is the project's critical path:**

Submit at `https://developer.apple.com/contact/request/family-controls-distribution`,
or via Certificates, Identifiers & Profiles → Capability requests.

- **Only the Account Holder can submit.** Not an Admin, not a Developer.
- **One request per bundle ID** — four total. Extensions are not covered by the app's
  approval. This is the most common mistake; missing one makes the upload fail with
  "missing com.apple.developer.family-controls".
- Write a substantive justification: name the bundle ID, the frameworks used, exactly
  what gets shielded, and the concrete user benefit. The one documented rejection was
  recovered by resubmitting a more detailed application.
- No SLA. Documented waits run from one week to five months. Escalate via a paid
  code-level support ticket if silent past four weeks.

Archive the confirmation emails in this directory.

After approval, verify the Capabilities list shows **Assigned**, and that
**Provisioning Support** lists App Store — otherwise the archive will not validate
even though the capability appears granted.

## Wiring the app target

Not yet wired, so that `CODE_SIGNING_ALLOWED=NO` builds stay green before the portal
work is done. To enable, add to both Debug and Release of the `Lumo` target:

```
CODE_SIGN_ENTITLEMENTS = Lumo/Lumo.entitlements;
```

## Deliberately NOT requested

Over-requesting restricted entitlements invites review questions, so this is explicit:

| Not requested | Why |
|---|---|
| `com.apple.developer.family-controls.app-and-website-usage` | Only for `FamilyActivityData`, which Apple restricts to **EU** devices in production. Deferred; the core loop does not need it. |
| Background Modes | `BGTaskScheduler` is deliberately unused — no timing guarantee, dies in Low Power Mode, dies when force-quit. Also a 2.5.4 concern. |
| Push Notifications / `aps-environment` | The expiry watchdog uses *local* notifications: runtime authorization, no entitlement. |
| HealthKit | Walk-to-earn is not in v1. When it lands, `CMPedometer` needs only `NSMotionUsageDescription`. |
| Keychain sharing, iCloud | No account, no server, no sync. |

## Reminder

Family Controls **does not function in the Simulator at all**, regardless of
entitlements. Device-only, and the device needs a passcode set and an iCloud sign-in.
