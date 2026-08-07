import LumoCore
import LumoShieldKit
import SwiftUI

/// Settings, including the escape hatch.
///
/// The teardown row is **permanently visible and never buried**. Competitor reviews include
/// *"impossible to delete: the app hides the delete button and sends to a feedback form"* and
/// *"one of the most dangerous applications I have ever installed."* An app that makes leaving
/// hard earns exactly that, and it is also an App Review problem.
struct SettingsView: View {

    @Environment(AuthorizationService.self) private var authorization
    @State private var isConfirmingTeardown = false
    @State private var releasedCount: Int?

    @State private var isShowingDebug = false
    @State private var isShowingManageApps = false

    var body: some View {
        NavigationStack {
            List {
                appsSection
                honestySection
                escapeSection
                diagnosticsSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.lumoInk)
            .navigationTitle("Settings")
        }
        .confirmationDialog(
            "Unlock everything?",
            isPresented: $isConfirmingTeardown,
            titleVisibility: .visible
        ) {
            Button("Unlock everything", role: .destructive) { tearDown() }
            Button("Cancel", role: .cancel) {}
        } message: {
            // Says exactly what survives. Someone leaving should not have to guess whether they
            // are also destroying their progress.
            Text("Every app opens again right away. Your coins and streak are kept, so you can pick up where you left off if you come back.")
        }
    }

    // MARK: - Apps

    /// The route back to both pickers.
    ///
    /// Absent until a device run exposed it: setup ran once, hasCompletedSetup latched, and there
    /// was no way to change the blocklist again. First item in Settings because it is the thing
    /// people will come here to do.
    private var appsSection: some View {
        Section {
            Button("Change your apps") { isShowingManageApps = true }
                .foregroundStyle(Color.lumoFlare)
        } header: {
            Text("Apps").foregroundStyle(Color.lumoHaze)
        }
        .sheet(isPresented: $isShowingManageApps) { ManageAppsView() }
    }

    // MARK: - Diagnostics

    private var diagnosticsSection: some View {
        Section {
            Button("Show diagnostics") { isShowingDebug = true }
                .foregroundStyle(Color.lumoHaze)
        } footer: {
            // Shipped rather than Debug-gated: when a user reports "it stopped locking", this is
            // the only thing that can say why.
            Text("If something isn't working, this shows Lumo's current state.")
                .foregroundStyle(Color.lumoHaze.opacity(0.8))
        }
        .sheet(isPresented: $isShowingDebug) { DebugPanelView() }
    }

    // MARK: - Honesty

    private var honestySection: some View {
        Section {
            row(
                "Lumo can't see what you do",
                detail: "iOS hands Lumo an anonymous marker for each app you pick. It never learns which apps they are, or what you do in them."
            )
            row(
                "Locking isn't unbreakable",
                detail: "You can always turn Lumo's access off in Settings, or delete the app. That's deliberate — a lock you can't undo is a trap, not a tool."
            )
            row(
                "Lumo is an ongoing arrangement",
                detail: "It won't rewire you and then step aside. The trade keeps working because it keeps being there."
            )
        } header: {
            Text("What Lumo can and can't do").foregroundStyle(Color.lumoHaze)
        } footer: {
            // Deliberately not a marketing claim. Every competitor eats one-star reviews for
            // platform bugs they never explain; explaining them is cheap and true.
            Text("Apple's Screen Time occasionally forgets which apps an app was told to lock. If something stops locking, reopening Lumo repairs it.")
                .foregroundStyle(Color.lumoHaze.opacity(0.8))
        }
    }

    // MARK: - Escape hatch

    private var escapeSection: some View {
        Section {
            Button {
                isConfirmingTeardown = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unlock everything and remove Lumo")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.lumoEmber)
                    // No Screen Time passcode, no support form, no delay. Stated up front so the
                    // user knows before tapping that this genuinely works.
                    Text("Opens every locked app immediately. No passcode needed.")
                        .font(.footnote)
                        .foregroundStyle(Color.lumoHaze)
                }
            }

            if let releasedCount {
                Label(
                    releasedCount == 0
                        ? "Nothing was locked."
                        : "\(releasedCount) app\(releasedCount == 1 ? "" : "s") unlocked. You can delete Lumo from your Home Screen.",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.footnote)
                .foregroundStyle(Color.lumoMoss)
            }
        } header: {
            Text("Leaving").foregroundStyle(Color.lumoHaze)
        }
    }

    private func row(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.body.weight(.medium)).foregroundStyle(.white)
            Text(detail).font(.footnote).foregroundStyle(Color.lumoHaze)
        }
        .padding(.vertical, 2)
    }

    @AppStorage("lumo.hasCompletedSetup") private var hasCompletedSetup = false

    private func tearDown() {
        // Reports zero rather than failing silently when the App Group is missing — in that case
        // there were no shields to release, so the user is not trapped either way.
        releasedCount = LumoStack.emergencyUnlock(for: .app)?.unlockEverything() ?? 0
        authorization.refresh()
        // Returning to setup, because "unlock everything" means starting over. Previously this
        // left the user on a home screen with no route back to either picker.
        hasCompletedSetup = false
    }
}
