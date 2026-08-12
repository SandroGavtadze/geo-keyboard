import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            OnboardingView()
                .tabItem { Label("Onboarding", systemImage: "info.circle") }

            DictionaryView()
                .tabItem { Label("Dictionary", systemImage: "book") }
        }
    }
}
