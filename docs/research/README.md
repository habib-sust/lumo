# Research

The evidence base for Lumo, committed alongside the code so that design decisions stay auditable.

| File | What it is | Authority |
|---|---|---|
| `00-product-plan.md` | Product plan: scope, economy design, P0 safety requirements, phases, testing scope | Authoritative on **product intent** |
| `01-architecture-spec.md` | Architecture and implementation spec: 74 tasks, cross-process state machine, sequence diagrams, concurrency model, risk register | Authoritative on **platform facts and API behaviour** — every Swift claim was typechecked against the shipped iOS 26.5 SDK |
| `02-science-and-competitive-dossier.md` | Behavioural-science evidence and competitive analysis, ~26k words, 25 numbered design principles with effect sizes | Authoritative on **behavioural evidence**. Its Apple-platform section was assembled from developer reports, not Apple's live docs — where it conflicts with `01`, `01` wins |

## Reading order

New to the project: `00` → `01` §0 (verification log) → `01` §13 (load-bearing decisions).
Implementing a task: `01` §8 for the task, then the section it references.
Writing user-facing or marketing copy: `02` "Verification debts" **first** — it logs six published
errors, non-existent papers, and fabricated statistics that circulate publicly.

## A note on the Screen Time API research

An earlier primary-source pass over Apple's documentation, WWDC 21/22, and the Developer Forums
informed the plan. Its findings are folded into `00` and were then **re-verified against the SDK** in
`01` §0, which corrected several of them — most importantly that iOS 26.5 added
`ShieldActionResponse.openParentalControlsApp` and `ManagedSettingsStore.refresh(_:)`, and that
`eventDidReachThreshold` still fires spuriously. Treat `01` §0 as the current record.

## Verification hygiene

`01` §0 was true against **Xcode 26.5 / iOS SDK 26.5**. Xcode 26.6 is current. Task T-002a re-diffs
the four `.swiftinterface` files before Phase 1 locks; record the result in `sdk-diff-26.6.md`.

Re-run the check with:

```sh
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
for F in ManagedSettings ManagedSettingsUI DeviceActivity FamilyControls; do
  echo "=== $F"
  cat "$SDK/System/Library/Frameworks/$F.framework/Modules/$F.swiftmodule/arm64e-apple-ios.swiftinterface"
done
```
