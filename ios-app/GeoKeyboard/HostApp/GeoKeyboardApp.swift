import SwiftUI

@main
struct GeoKeyboardApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                OnboardingView()
                    .tabItem { Label("დაყენება", systemImage: "keyboard") }
                SettingsView()
                    .tabItem { Label("პარამეტრები", systemImage: "gearshape") }
            }
        }
    }
}

struct OnboardingView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("კლავიატურის ჩართვა · Enable the keyboard") {
                    Label("Open Settings → General → Keyboard → Keyboards", systemImage: "1.circle")
                    Label("Add New Keyboard… → GeoKeyboard", systemImage: "2.circle")
                    Label("In any app, hold 🌐 and pick GeoKeyboard", systemImage: "3.circle")
                }
                Section {
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                Section("როგორ მუშაობს · How it works") {
                    Text("დაწერე ლათინურად — *saxlshi xar* — და კლავიატურა გადაიყვანს ქართულად: **სახლში ხარ**. Space ადასტურებს პირველ ვარიანტს; Backspace აბრუნებს.")
                    Text("Full Access არ არის საჭირო. ყველაფერი მუშაობს შენს ტელეფონზე — არაფერი იგზავნება ინტერნეტში.")
                }
            }
            .navigationTitle("GeoKeyboard")
        }
    }
}

struct SettingsView: View {
    @State private var mode = AppSettings.defaultMode
    @State private var autocorrect = AppSettings.autocorrectEnabled

    var body: some View {
        NavigationStack {
            Form {
                Section("ძირითადი განლაგება · Default layout") {
                    Picker("Layout", selection: $mode) {
                        ForEach(AppSettings.KeyboardMode.allCases) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    Text("კლავიატურაზე аბგ/abc ღილაკით ნებისმიერ დროს გადართავ.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Toggle("ავტოკორექცია · Autocorrect on space", isOn: $autocorrect)
                }
            }
            .navigationTitle("პარამეტრები")
            .onChange(of: mode) { _, new in AppSettings.defaultMode = new }
            .onChange(of: autocorrect) { _, new in AppSettings.autocorrectEnabled = new }
        }
    }
}
