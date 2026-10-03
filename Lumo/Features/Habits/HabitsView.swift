import LumoCore
import SwiftUI

/// Where coins come from.
///
/// One generic timer habit the user names and sets a target for — not a catalogue of pre-defined
/// activities. The user authoring their own standard is what makes performance-contingent rewards
/// fair rather than imposed, and autonomy support is one of the few overjustification mitigations
/// with real evidence behind it.
struct HabitsView: View {

    @Environment(HabitService.self) private var habits
    @Environment(\.dismiss) private var dismiss

    @State private var isCreating = false
    @State private var logging: HabitSpec?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lumoInk.ignoresSafeArea()
                content
            }
            .navigationTitle("Your habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isCreating = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("habits.add")
                    .accessibilityLabel("Add a habit")
                }
            }
            .sheet(isPresented: $isCreating) { NewHabitSheet() }
            .sheet(item: $logging) { habit in
                RetroactiveLogSheet(habit: habit)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if habits.habits.isEmpty {
            ScrollView {
                VStack(spacing: 20) {
                    LumoEmptyState(
                        symbol: "leaf",
                        title: "Start with one small thing",
                        detail: "Read a chapter, take a walk, or finish a chore. Set your own target and earn time for your apps."
                    )
                    PrimaryButton("Create a habit", isBusy: false) { isCreating = true }
                        .accessibilityIdentifier("habits.createFirst")
                }
                .padding(LumoSpace.margin)
            }
        } else {
            List {
                LumoSectionHeading(title: "Build your own rhythm", subtitle: "Choose something meaningful. Small sessions count.")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                ForEach(habits.habits) { habit in
                    row(habit)
                        .listRowBackground(Color.lumoSoot)
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func row(_ habit: HabitSpec) -> some View {
        VStack(alignment: .leading, spacing: LumoSpace.tight) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.lumoHeadline)
                        .foregroundStyle(Color.lumoText)
                    Text(
                        habit.isMonetised
                            ? "\(habit.targetMinutes) min target"
                            : "\(habit.targetMinutes) min target · no coins, by choice"
                    )
                    .lumoSecondary()
                }
                Spacer()
            }
            HStack(spacing: LumoSpace.snug) {
                Button("Start") { habits.start(habit) }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.lumoAccentFill)
                    .foregroundStyle(Color.lumoOnAccent)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.lumoFlare, lineWidth: 1)
                    }
                    .disabled(habits.timer != nil)
                    .accessibilityIdentifier("habits.start.\(habit.id.uuidString)")
                // Forgetting to press start is not a reason to lose the work. Its absence is a
                // recurring competitor complaint, and a timer you must remember measures
                // app-opening rather than the habit.
                Button("Log it") { logging = habit }
                    .buttonStyle(.bordered)
                    .tint(Color.lumoHaze)
                Spacer()
            }
        }
        .padding(.vertical, LumoSpace.snug)
        .swipeActions {
            Button("Archive", role: .destructive) { habits.archive(habit) }
        }
    }
}

/// Create a habit.
struct NewHabitSheet: View {
    @Environment(HabitService.self) private var habits
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var targetMinutes = 10
    @State private var isMonetised = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What is it?", text: $name)
                        .accessibilityIdentifier("newHabit.name")
                    Stepper(
                        "Target: \(targetMinutes) min",
                        value: $targetMinutes, in: 1...180, step: 5
                    )
                } footer: {
                    Text("A session shorter than your target still counts toward your streak — it just doesn't pay. You set the bar, so it should be one you'd actually clear.")
                }

                Section {
                    Toggle("Earn coins for this", isOn: $isMonetised)
                } footer: {
                    // The un-monetised list is a real feature, not an oversight. Attaching rewards
                    // to something the user already enjoys is the precondition for undermining it —
                    // the effect needs pre-existing intrinsic motivation to destroy.
                    Text("Turn this off for things you already want to do. Paying yourself for those is the one case where the reward can backfire.")
                }
            }
            .navigationTitle("New thing to do")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        habits.create(
                            name: name, targetMinutes: targetMinutes, isMonetised: isMonetised)
                        dismiss()
                    }
                    .accessibilityIdentifier("newHabit.add")
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

/// Log a session that already happened.
struct RetroactiveLogSheet: View {
    let habit: HabitSpec

    @Environment(HabitService.self) private var habits
    @Environment(\.dismiss) private var dismiss

    @State private var minutes = 10

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("\(minutes) min", value: $minutes, in: 1...180, step: 5)
                } header: {
                    Text("How long did you spend on \(habit.name)?")
                } footer: {
                    Text("Recorded as logged after the fact, which is honest and keeps your own history readable.")
                }
            }
            .navigationTitle("Log it")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        habits.logRetroactive(habit, minutes: minutes)
                        dismiss()
                    }
                    .accessibilityIdentifier("log.save")
                }
            }
        }
    }
}
