import SwiftUI

/// How the buddy is feeling. **There is no unwell case, and adding one is a design regression.**
///
/// Every competitor in this category chose punishment — Unrot's buddy loses energy when you scroll,
/// Brainrot's avatar decays, Forest kills your tree — and the app with by far the best retention in
/// the dossier chose the opposite: *"your bird never dies, streaks never punish you, and missing a
/// day costs you nothing."* Habitica demonstrates the other direction, churning users while also
/// failing to motivate them.
///
/// So the range runs from **sleepy to bright**, never from sick to healthy. A user who has not
/// earned in a week finds their buddy dozing, not dying. The agreed tone is *sleepy, never sick*.
enum BuddyMood: Equatable {
    /// Low balance, or nothing done in a while. Dozing, content, in no distress.
    case sleepy
    /// The resting state.
    case calm
    /// Plenty banked.
    case bright
    /// The one orchestrated moment: a habit was just completed.
    case delighted

    /// Maps warmth to mood, so the buddy and the light are the same signal rather than two.
    static func forWarmth(_ warmth: Double) -> BuddyMood {
        switch warmth {
        case ..<0.15: .sleepy
        case ..<0.6: .calm
        default: .bright
        }
    }
}

/// The seam that lets a real animation system replace this later.
///
/// Vector-and-SwiftUI now, deliberately: it is the version that ships, costs no dependency and no
/// bundle size, and does not link a rendering engine into a project that already guards a 6 MB
/// extension ceiling. Rive or a sprite sheet becomes a second conformance and a one-line change at
/// the call site.
protocol BuddyRendering: View {
    init(mood: BuddyMood)
}

/// The shipping buddy: a warm, rounded, sleepy thing made of two arcs and two eyes.
///
/// Intentionally simple. A character with a lot of detail invites a lot of *states*, and states in
/// this category slide towards decay mechanics almost automatically.
struct VectorBuddy: BuddyRendering {
    let mood: BuddyMood

    init(mood: BuddyMood) {
        self.mood = mood
    }

    @State private var breathing = false

    var body: some View {
        ReduceMotionReader { reduceMotion in
            ZStack {
                body(reduceMotion: reduceMotion)
                eyes
            }
            .frame(width: 132, height: 132)
            .onAppear {
                // Guarded rather than started-and-stopped: a `repeatForever` animation cannot be
                // cancelled once running, so under Reduce Motion it must never begin.
                guard !reduceMotion else { return }
                withAnimation(LumoMotion.breathe) { breathing = true }
            }
            .lumoAnimation(LumoMotion.surge, value: mood)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityDescription)
        }
    }

    private func body(reduceMotion: Bool) -> some View {
        let scale = reduceMotion ? 1.0 : (breathing ? 1.03 : 0.985)
        return Circle()
            .fill(
                RadialGradient(
                    colors: [.lumoFlare.opacity(glow), .lumoEmber.opacity(glow * 0.75)],
                    center: .init(x: 0.42, y: 0.36),
                    startRadius: 4,
                    endRadius: 96
                )
            )
            .scaleEffect(mood == .delighted ? scale * 1.08 : scale)
    }

    /// Closed when sleepy, open otherwise, curved upward when delighted.
    ///
    /// Note there is no *frown*. The buddy has no way to express disappointment in the user, which
    /// is a constraint on the art rather than a gap in it — shaming copy and shaming characters are
    /// directly cited in competitor 1–2★ reviews as the reason people uninstalled.
    private var eyes: some View {
        HStack(spacing: 22) {
            ForEach([-1.0, 1.0], id: \.self) { side in
                eye(mirrored: side < 0)
            }
        }
        .offset(y: -6)
    }

    private func eye(mirrored: Bool) -> some View {
        Group {
            switch mood {
            case .sleepy:
                Capsule()
                    .fill(Color.lumoInk.opacity(0.75))
                    .frame(width: 18, height: 4)
            case .delighted:
                Arc()
                    .stroke(Color.lumoInk.opacity(0.8), style: .init(lineWidth: 4, lineCap: .round))
                    .frame(width: 18, height: 10)
                    .scaleEffect(x: mirrored ? -1 : 1)
            case .calm, .bright:
                Circle()
                    .fill(Color.lumoInk.opacity(0.75))
                    .frame(width: 9, height: 9)
            }
        }
    }

    private var glow: Double {
        switch mood {
        case .sleepy: 0.55
        case .calm: 0.75
        case .bright: 0.92
        case .delighted: 1.0
        }
    }

    private var accessibilityDescription: String {
        switch mood {
        case .sleepy: "Your buddy is dozing."
        case .calm: "Your buddy is resting."
        case .bright: "Your buddy is bright and awake."
        case .delighted: "Your buddy is delighted."
        }
    }
}

/// A simple upward arc, for the delighted eyes.
private struct Arc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY - rect.height)
        )
        return path
    }
}

#Preview("Buddy moods") {
    HStack(spacing: 0) {
        ForEach([BuddyMood.sleepy, .calm, .bright, .delighted], id: \.self) { mood in
            VectorBuddy(mood: mood).scaleEffect(0.7)
        }
    }
    .lumoBackground()
}
