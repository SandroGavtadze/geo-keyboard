import StoreKit
import SwiftUI

struct ProView: View {
    @EnvironmentObject private var store: ProStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GeoKeyboard Pro")
                            .font(.title2.bold())
                        Text("ერთჯერადი გადახდა. გამოწერის და რეკლამის გარეშე.")
                        Text("One-time purchase. No subscription, no ads.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                Section("რას იღებ · What you get") {
                    Label("შემდეგი სიტყვის შეთავაზება · Next-word predictions", systemImage: "text.bubble")
                    Label("მომავალი Pro ფუნქციები · Future Pro features", systemImage: "sparkles")
                }
                Section {
                    if store.isUnlocked {
                        Label("Pro გააქტიურებულია · Pro unlocked", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            Task { await store.purchase() }
                        } label: {
                            HStack {
                                Text("Pro-ს გახსნა · Unlock Pro")
                                Spacer()
                                if let product = store.product {
                                    Text(product.displayPrice)
                                } else {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(store.product == nil || store.isWorking)
                    }
                    Button("შენაძენის აღდგენა · Restore Purchase") {
                        Task { await store.restore() }
                    }
                    .disabled(store.isWorking)
                } footer: {
                    Text("ლათინურით წერა, ცოცხალი გადაყვანა და ავტოკორექცია ყოველთვის უფასოა.\nTyping, live conversion and autocorrect are always free.")
                }
            }
            .navigationTitle("Pro")
            .alert("შეცდომა · Error", isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
    }
}
