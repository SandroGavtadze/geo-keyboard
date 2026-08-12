import SwiftUI
import GeorgianIME

struct DictionaryView: View {
    @State private var newWord: String = ""
    @State private var words: [(String, Int)] = []

    private var store: UserLexiconStore {
        let path = AppGroup.sqlitePath()
        let sqlite = try! SQLiteStore(path: path)
        return UserLexiconStore(store: sqlite)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Add word", text: $newWord)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    let w = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !w.isEmpty else { return }
                    store.markAccepted(word: w, prev: nil)
                    newWord = ""
                    reload()
                }
            }

            List {
                ForEach(words, id: \.0) { item in
                    HStack {
                        Text(item.0)
                        Spacer()
                        Text(String(item.1)).foregroundColor(.secondary)
                    }
                }
                .onDelete { idx in
                    for i in idx { store.delete(word: words[i].0) }
                    reload()
                }
            }

            Button("Reset Dictionary") {
                store.reset()
                reload()
            }
            .foregroundColor(.red)

        }
        .padding()
        .onAppear { reload() }
    }

    private func reload() {
        words = store.listUserWords()
    }
}
