import FamilyControls
import LumoCore
import LumoShieldKit
import SwiftUI

/// Change which apps are protected and which are locked, after setup.
///
/// This was missing entirely until a device run exposed it: setup ran once, `hasCompletedSetup`
/// latched, and there was then no route back to either picker. A blocklist you cannot edit is not a
/// usable product — people change their minds, install new apps, and need to protect something they
/// forgot.
///
/// Both pickers are presented from this dedicated screen rather than nested inside another sheet,
/// because `FamilyActivityPicker` is reported to crash when buried in a sheet stack.
struct ManageAppsView: View {

    @Environment(SelectionService.self) private var selection
    @Environment(\.dismiss) private var dismiss

    @State private var isEssentialPickerPresented = false
    @State private var isBlockPickerPresented = false
    @State private var saved = false
    @State private var committed: (apps: Int, categories: Int, essential: Int)?

    var body: some View {
        NavigationStack {
            List {
                currentSection
                essentialSection
                blockSection
                saveSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.lumoInk)
            .navigationTitle("Your apps")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { committed = selection.loadCommittedCounts() }
        // Both pickers attach to this screen, never to a nested sheet.
        .familyActivityPicker(
            headerText: "Never lock these",
            footerText: "Anything you choose here stays open, always.",
            isPresented: $isEssentialPickerPresented,
            selection: Binding(
                get: { selection.essentialSelection },
                set: { selection.essentialSelection = $0 }
            )
        )
        .familyActivityPicker(
            headerText: "Lock these until you earn",
            footerText: "Lumo never sees which apps you pick — iOS keeps that private, even from us.",
            isPresented: $isBlockPickerPresented,
            selection: Binding(
                get: { selection.blockSelection },
                set: { selection.blockSelection = $0 }
            )
        )
    }

    /// What is actually persisted right now.
    ///
    /// Shown separately from the pending picker counts because the two genuinely differ: tokens are
    /// opaque, so a previous selection cannot be loaded back into the picker. Conflating them would
    /// make it look as though nothing was saved.
    private var currentSection: some View {
        Section {
            if let committed {
                HStack {
                    Text("Locked now").foregroundStyle(.white)
                    Spacer()
                    Text("\(committed.apps) apps, \(committed.categories) categories")
                        .font(.callout.monospaced())
                        .foregroundStyle(Color.lumoMoss)
                }
                HStack {
                    Text("Protected now").foregroundStyle(.white)
                    Spacer()
                    Text("\(committed.essential)")
                        .font(.callout.monospaced())
                        .foregroundStyle(Color.lumoMoss)
                }
            } else {
                Text("Nothing saved yet").foregroundStyle(Color.lumoHaze)
            }
        } header: {
            Text("Saved").foregroundStyle(Color.lumoHaze)
        } footer: {
            Text("iOS keeps your choices private, so Lumo can show how many apps are set but not which ones. Re-picking replaces the list.")
                .foregroundStyle(Color.lumoHaze.opacity(0.8))
        }
    }

    private var essentialSection: some View {
        Section {
            Button("Choose apps to protect") { isEssentialPickerPresented = true }
                .foregroundStyle(Color.lumoMoss)
            if selection.essentialCount > 0 {
                Text("\(selection.essentialCount) selected")
                    .font(.footnote).foregroundStyle(Color.lumoHaze)
            }
        } header: {
            Text("Never lock").foregroundStyle(Color.lumoHaze)
        } footer: {
            Text("Phone, messages, maps, wallet, and any medical app. Lumo can't tell what an app does, so it can't protect these for you automatically.")
                .foregroundStyle(Color.lumoHaze.opacity(0.8))
        }
    }

    private var blockSection: some View {
        Section {
            Button("Choose apps to lock") { isBlockPickerPresented = true }
                .foregroundStyle(Color.lumoEmber)
            if selection.blockedAppCount > 0 {
                HStack {
                    Text("\(selection.blockedAppCount) of \(selection.appCap)")
                        .font(.callout.monospaced())
                        .foregroundStyle(selection.isOverCap ? Color.lumoEmber : .white)
                    Spacer()
                    if selection.isOverCap {
                        Text("over the limit").font(.footnote).foregroundStyle(Color.lumoEmber)
                    }
                }
            }
        } header: {
            Text("Lock until earned").foregroundStyle(Color.lumoHaze)
        }
    }

    private var saveSection: some View {
        Section {
            Button("Save") {
                // Essential is saved even when the blocklist is empty, so clearing the blocklist
                // never discards protection.
                if selection.blockedAppCount > 0 {
                    saved = selection.commit()
                } else {
                    saved = selection.commitEssentialOnly()
                }
                committed = selection.loadCommittedCounts()
            }
            .foregroundStyle(selection.isOverCap ? Color.lumoHaze : Color.lumoFlare)
            .disabled(selection.isOverCap)

            if let failure = selection.commitError {
                Text(failure.message).font(.footnote).foregroundStyle(Color.lumoEmber)
            } else if saved {
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .font(.footnote).foregroundStyle(Color.lumoMoss)
            }
        }
    }
}
