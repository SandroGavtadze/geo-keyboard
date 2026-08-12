import SwiftUI

struct OnboardingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enable Georgian Keyboard")
                .font(.title2).bold()

            Text("1) Settings → General → Keyboard → Keyboards → Add New Keyboard…")
            Text("2) Select GeorgianKeyboard")
            Text("3) Turn ON: GeorgianKeyboard")
            Text("4) Full Access is NOT required for on-device learning.")

            Spacer()
        }
        .padding()
    }
}
