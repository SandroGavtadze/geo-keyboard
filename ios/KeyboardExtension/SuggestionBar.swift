import SwiftUI
import GeorgianIME

struct SuggestionBar: View {
    let suggestions: [Suggestion]
    let onTap: (Suggestion) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(suggestions, id: \.self) { s in
                Button(action: { onTap(s) }) {
                    Text(s.text.isEmpty ? " " : s.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
