import FamilyControls
import LumoCore
import SwiftUI

/// The setup flow.
///
/// Step order is a safety decision, not a UX preference: **essential apps are chosen before the
/// blocklist.** A competitor's reviewer wrote *"I am a type 1 diabetic and it would block my
/// pump… I can die from that."* Asking afterwards would mean a window in which the user has
/// shielded everything and not yet protected anything.
struct OnboardingFlow: View {

    @State private var step: Step = .authorize
    @Environment(AuthorizationService.self) private var authorization
    @Environment(SelectionService.self) private var selection

    /// Called when setup finishes — including when the user opts out of locking entirely.
    var onFinished: () -> Void

    enum Step: Int, CaseIterable {
        case authorize
        case essentialApps
        case blockList
        case done
    }

    var body: some View {
        ZStack {
            Color.lumoInk.ignoresSafeArea()

            switch step {
            case .authorize:
                AuthorizationStep(
                    onGranted: { step = .essentialApps },
                    onSkipped: onFinished
                )
            case .essentialApps:
                EssentialAppsStep(onNext: { step = .blockList })
            case .blockList:
                BlockListStep(onDone: { step = .done })
            case .done:
                SetupCompleteStep(onFinished: onFinished)
            }
        }
        .animation(.snappy, value: step)
    }
}

// MARK: - Step 1: authorization

private struct AuthorizationStep: View {
    @Environment(AuthorizationService.self) private var authorization
    var onGranted: () -> Void
    var onSkipped: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.open.rotation")
                .font(.system(size: 48))
                .foregroundStyle(Color.lumoEmber)

            VStack(spacing: 10) {
                Text(authorization.guidance?.title ?? "Let Lumo lock apps")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(authorization.guidance?.explanation
                     ?? "Lumo uses Apple's Screen Time to lock the apps you choose. It never sees what you do in them.")
                    .font(.callout)
                    .foregroundStyle(Color.lumoHaze)
                    .multilineTextAlignment(.center)

                if let path = authorization.guidance?.settingsPath {
                    Text(path)
                        .font(.footnote.monospaced())
                        .foregroundStyle(Color.lumoHaze)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 12) {
                if authorization.isAuthorized {
                    PrimaryButton("Continue", isBusy: false, action: onGranted)
                } else if let guidance = authorization.guidance, !guidance.isRetryable {
                    // No retry button when retrying cannot work — a button that fails again is
                    // worse than none.
                    EmptyView()
                } else {
                    PrimaryButton(
                        authorization.guidance?.actionLabel ?? "Turn on app locking",
                        isBusy: authorization.isRequesting
                    ) {
                        Task { await authorization.request() }
                    }
                }

                // ALWAYS present, on every branch above. Guideline 5.1.2(i) forbids requiring a
                // system capability to use the app, and trapping someone at a permission wall
                // they cannot clear is how an app gets deleted.
                Button(AuthorizationCopy.continueWithoutLocking, action: onSkipped)
                    .font(.callout)
                    .foregroundStyle(Color.lumoHaze)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onChange(of: authorization.status) { _, status in
            if status.isAuthorized { onGranted() }
        }
    }
}

// MARK: - Step 2: essential apps

private struct EssentialAppsStep: View {
    @Environment(SelectionService.self) private var selection
    @State private var isPickerPresented = false
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "cross.case.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.lumoMoss)

            VStack(spacing: 10) {
                Text("First — what must never be locked?")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Pick anything you might need urgently: your phone, messages, maps, wallet, and especially any medical app — a glucose monitor, insulin pump, or medication reminder.")
                    .font(.callout)
                    .foregroundStyle(Color.lumoHaze)
                    .multilineTextAlignment(.center)

                // Honest about the platform limit. iOS gives Lumo opaque tokens, so it genuinely
                // cannot recognise a medical app on its own — promising automatic protection we
                // cannot deliver would be worse than saying nothing.
                Text("Lumo can't tell what an app does, so it can't protect these automatically. Whatever you pick here is never locked.")
                    .font(.footnote)
                    .foregroundStyle(Color.lumoHaze.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 28)

            if selection.essentialCount > 0 {
                Label("\(selection.essentialCount) protected", systemImage: "checkmark.shield.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Color.lumoMoss)
            }

            Spacer()

            VStack(spacing: 12) {
                PrimaryButton("Choose apps to protect", isBusy: false) {
                    isPickerPresented = true
                }
                Button(selection.essentialCount > 0 ? "Next" : "Skip for now", action: onNext)
                    .font(.callout)
                    .foregroundStyle(Color.lumoHaze)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        // Presented from a dedicated screen rather than nested in a sheet stack: the picker is
        // reported to crash when buried, and on large category expansion.
        .familyActivityPicker(
            headerText: "Never lock these",
            footerText: "Anything you choose here stays open, always.",
            isPresented: $isPickerPresented,
            selection: Binding(
                get: { selection.essentialSelection },
                set: { selection.essentialSelection = $0 }
            )
        )
    }
}

// MARK: - Step 3: blocklist

private struct BlockListStep: View {
    @Environment(SelectionService.self) private var selection
    @State private var isPickerPresented = false
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "hourglass")
                .font(.system(size: 44))
                .foregroundStyle(Color.lumoEmber)

            VStack(spacing: 10) {
                Text("Now — what steals your evening?")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("These stay locked until you've earned coins. You can change them any time.")
                    .font(.callout)
                    .foregroundStyle(Color.lumoHaze)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)

            // Live count, so the cap is visible before the user hits it rather than after.
            VStack(spacing: 6) {
                Text("\(selection.blockedAppCount) of \(selection.appCap)")
                    .font(.system(.title3, design: .monospaced).weight(.medium))
                    .foregroundStyle(selection.isOverCap ? Color.lumoEmber : .white)
                Text(selection.isOverCap
                     ? "That's more than iOS allows Lumo to lock at once."
                     : "apps selected")
                    .font(.footnote)
                    .foregroundStyle(selection.isOverCap ? Color.lumoEmber : Color.lumoHaze)
            }

            if let failure = selection.commitError {
                Text(failure.message)
                    .font(.footnote)
                    .foregroundStyle(Color.lumoEmber)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            Spacer()

            VStack(spacing: 12) {
                PrimaryButton("Choose apps to lock", isBusy: false) {
                    isPickerPresented = true
                }
                PrimaryButton(
                    "Lock these apps",
                    isBusy: false,
                    isEnabled: selection.blockedAppCount > 0 && !selection.isOverCap
                ) {
                    if selection.commit() { onDone() }
                }
                Button("Skip for now", action: onDone)
                    .font(.callout)
                    .foregroundStyle(Color.lumoHaze)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .familyActivityPicker(
            headerText: "Lock these until you earn",
            footerText: "Lumo never sees which apps you pick — iOS keeps that private, even from us.",
            isPresented: $isPickerPresented,
            selection: Binding(
                get: { selection.blockSelection },
                set: { selection.blockSelection = $0 }
            )
        )
    }
}

// MARK: - Step 4: done

private struct SetupCompleteStep: View {
    @Environment(SelectionService.self) private var selection
    var onFinished: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "flame.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.lumoFlare)

            Text("Locked.")
                .font(.title.weight(.semibold))
                .foregroundStyle(.white)

            Text("Do something first. Then scroll.")
                .font(.callout)
                .foregroundStyle(Color.lumoHaze)

            if let outcome = selection.lastOutcome, !outcome.refusedAsEssential.isEmpty {
                // Explaining a silent refusal, rather than letting the user wonder why an app they
                // picked is still open.
                Text("\(outcome.refusedAsEssential.count) stayed open because you marked them essential.")
                    .font(.footnote)
                    .foregroundStyle(Color.lumoMoss)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            Spacer()
            PrimaryButton("Start", isBusy: false, action: onFinished)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
    }
}
