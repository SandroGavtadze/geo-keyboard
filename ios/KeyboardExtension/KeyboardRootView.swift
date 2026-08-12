import SwiftUI
import GeorgianIME

enum KeyAction {
    case insert(String)
    case backspace
    case space
    case returnKey
    case nextKeyboard
    case noop
}

struct KeyboardRootView: View {
    var onKey: (KeyAction) -> Void
    var fetchSuggestions: () -> [Suggestion]
    var onAcceptSuggestion: (Suggestion) -> Void

    @State private var mode: KeyboardMode = .letters
    @State private var shiftOn: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            SuggestionBar(suggestions: fetchSuggestions(), onTap: onAcceptSuggestion)

            KeyboardView(
                mode: $mode,
                shiftOn: $shiftOn,
                onKey: onKey
            )
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(Color(white: 0.85))
    }
}

enum KeyboardMode { case letters, numbers, symbols }
