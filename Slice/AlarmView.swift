import SwiftUI

/// Contents of the alarm window: what ended, and one big Dismiss button.
struct AlarmView: View {
    let title: String
    let message: String
    /// Called when the user clicks Dismiss (or presses Return).
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "alarm.fill")
                .font(.system(size: 44))
                .foregroundStyle(.red)
            Text(title)
                .font(.title)
                .bold()
            Text(message)
                .foregroundStyle(.secondary)
            Button("Dismiss", action: onDismiss)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
        .padding(32)
        .frame(width: 360)
    }
}

#Preview {
    AlarmView(title: "Work done", message: "Take a break.") {}
}
