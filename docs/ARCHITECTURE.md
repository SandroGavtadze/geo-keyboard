# Architecture Decisions

## Goals
- Provide a Georgian keyboard on iOS that mimics the layout in the provided screenshot.
- Provide on-device spell-check + suggestions and on-device learning ("remember words").
- Work without network access and without requiring "Full Access".

## Key iOS Constraints
- Keyboard extensions are memory/time constrained; keep compute bounded and fast.
- Access to context is limited to `textDocumentProxy` (often only a small window).
- Without "Full Access", no network access. Local storage is still allowed.
- Use **App Group** storage so both the host app and keyboard extension can share:
  - user dictionary
  - frequencies
  - settings

## High-level Components
1. **Host App**
   - Onboarding instructions to enable the keyboard.
   - Settings: autocorrect on/off, learning on/off, reset dictionary.
   - Personal dictionary UI: add/remove words.

2. **Keyboard Extension**
   - Renders keys from JSON layout data.
   - Maintains shift/123/symbol states.
   - Suggestion strip (top 3–5) showing:
     - original token (verbatim)
     - top corrections
     - next-word predictions when token is empty

3. **Language Engine (Swift Package)**
   - Tokenizer: extracts current token and previous token from limited context.
   - Lexicon: base word list + user words.
   - Candidate generation: bounded edit-distance (Damerau-Levenshtein-like ops).
   - Ranking: distance, lexicon presence, user frequency, optional bigrams.

4. **Persistence**
   - SQLite in App Group container.
   - Tables:
     - `user_words(word TEXT PRIMARY KEY, count INT, last_seen INT)`
     - `bigrams(prev TEXT, word TEXT, count INT, PRIMARY KEY(prev, word))`
     - `settings(key TEXT PRIMARY KEY, value TEXT)`

## Spell-check Strategy (Incremental)
### MVP
- Base lexicon lookup (wordlist file).
- If token not found:
  - generate edit-distance=1 candidates (cap N)
  - rank and show suggestions
- Learn words:
  - explicit "Add" action from suggestion bar
  - implicit: after N repeated uses, promote token to user dictionary

### Next iterations
- Edit-distance=2 for short words (length <= 6), still bounded.
- Keyboard adjacency confusion sets based on Georgian key neighbors.
- Bigram next-word suggestions from on-device counts.

## Performance Guardrails
- Hard cap candidate generation per keystroke (e.g., 200).
- Cache last token -> suggestion list.
- Do heavy work on background queue, update UI on main thread.
- Lexicon search should be O(log n) (sorted array) or O(1) (hash) after load.

## Privacy
- On-device only.
- Do not transmit typed content.
- Provide a clear in-app statement and include it in App Store description.
