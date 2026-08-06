import SwiftUI

/// The one filled button style, so calls to action stay consistent across the flow.
///
/// Copy convention: an action names exactly what happens when it is used and keeps that name
/// through the flow — "Lock these apps" produces locked apps. Never "Submit", never "Continue"
/// where something more specific is true.
struct PrimaryButton: View {
    let title: String
    let isBusy: Bool
    var isEnabled = true
    let action: () -> Void

    init(_ title: String, isBusy: Bool, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isBusy = isBusy
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Kept in the layout while busy so the button does not resize mid-tap.
                Text(title)
                    .opacity(isBusy ? 0 : 1)
                if isBusy {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color.lumoInk)
                }
            }
            .font(.headline)
            .foregroundStyle(Color.lumoInk)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(isEnabled ? Color.lumoFlare : Color.lumoHaze.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(!isEnabled || isBusy)
        // Dynamic Type is honoured rather than clamped: this button carries the flow's only
        // forward action, so it must stay legible at accessibility sizes.
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}
