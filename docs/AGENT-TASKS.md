# AI Agent Task List (Execution Plan)

## 0) Repo assumptions
- Swift 5.9+ (or latest stable in Xcode).
- SwiftUI host app.
- Keyboard extension uses UIKit (`UIInputViewController`) with SwiftUI hosted views.

## 1) Create Xcode project + targets
1. Create iOS App (SwiftUI) named `GeorgianKeyboard`.
2. Add target: **Keyboard Extension** named `GeorgianKeyboardExtension`.
3. Add local Swift Package: `engine/GeorgianIME`.

Acceptance:
- Build succeeds with both targets.

## 2) Configure App Group
1. In Signing & Capabilities for both targets:
   - Add **App Groups**
   - Create: `group.com.yourcompany.georgiankeyboard`
2. Update `ios/Shared/AppGroup.swift` constant to match.

Acceptance:
- Host app can read/write a test value and keyboard extension reads it.

## 3) Wire keyboard UI
1. Copy files from `ios/KeyboardExtension/` into the extension target.
2. Ensure layout JSON is bundled into extension target (`layouts/*.json`).
3. Implement:
   - letters view using `ka_letters.json`
   - shift toggle
   - backspace repeat (press & hold)
   - space and return

Acceptance:
- Typing inserts Georgian letters in any text field.
- Layout matches the screenshot (rows/ordering).

## 4) Implement suggestion bar plumbing
1. Copy `ios/KeyboardExtension/SuggestionBar.swift`.
2. On each text change / key tap, call:
   - `engine.suggest(token:prevToken:)`
3. Tapping a suggestion commits replacement for current token.

Acceptance:
- Suggestions appear for misspelled tokens.
- Tap suggestion replaces the current word.

## 5) Engine MVP
1. Ensure `engine/` package compiles.
2. Add a base lexicon:
   - Place a word list at `engine/Resources/ka_wordlist.txt`
   - Format: one word per line, lowercase Mkhedruli.
3. Implement `Lexicon.contains(word:)` and `Lexicon.prefixSearch(_:)` if needed.

Acceptance:
- Unknown words produce correction candidates.

## 6) Persistence + learning
1. Use `SQLiteStore` in App Group container.
2. Implement:
   - `recordAccepted(word:prev:)`
   - `shouldTrust(word:)` (after N uses or in user_words)
3. Add host app UI:
   - Add/remove word from user dictionary
   - Reset dictionary

Acceptance:
- A repeatedly typed unknown word stops being corrected after threshold.
- User-added word is always treated as correct.

## 7) Autocorrect on space + undo
1. If enabled and token misspelled:
   - apply best correction on space
2. If next action is backspace:
   - undo correction and restore original token

Acceptance:
- Works like iOS autocorrect behavior.

## 8) QA checklist
- Works in Messages, Notes, Safari.
- No crashes on fast typing.
- Suggestions update quickly (<50ms typical on device).
- All learning stays on device; no network calls.
