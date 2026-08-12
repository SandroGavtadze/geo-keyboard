# geo-keyboard — ქართული კლავიატურა

A Georgian keyboard for iPhone/iPad that lets you **type in Latin letters and get Georgian**, the way Georgians abroad already write: `saxlshi xar?` → `სახლში ხარ?` — with spellcheck, autocorrect, and next-word prediction.

## Why

In the US (and everywhere outside Georgia) people type Georgian phonetically in Latin letters. No mainstream keyboard converts this well. The goal is a keyboard good enough that it becomes the default way Georgians type on iOS.

## How it works (pinyin-style IME)

Latin sequences map *ambiguously* to Georgian letters (`t`→თ/ტ, `k`→კ/ქ, `ch`→ჩ/ჭ, `ts`→ც/წ, `dz`→ძ, `w`→წ, `x`→ხ …). The engine:

1. Explores every plausible segmentation of the Latin input (`sh` = შ or ს+ჰ),
2. prunes against a **trie of a 49k-word frequency-ranked Georgian dictionary**, so only real-word paths survive,
3. ranks candidates by word frequency minus mapping-convention penalties,
4. offers prefix completions and (after a word is committed) bigram next-word predictions.

Everything runs on-device. No network, no "Full Access" needed.

**Current prototype accuracy:** 92.7% top-1, 100% top-3 on an 82-phrase test set of informal translit; ~0.04 ms per keystroke.

## Repo layout

```
engine/translit.js   reference engine implementation (JS) — will be ported to Swift
engine/test.js       accuracy + latency harness (node engine/test.js)
data/ka_words_freq.tsv   49,257 Georgian words with corpus frequencies
data/ka_bigrams.tsv      22,634 word bigrams for next-word prediction
demo/template.html   demo source (dictionary + engine get inlined at build)
demo/build.py        builds demo/index.html
demo/index.html      ⭐ self-contained interactive prototype — open in any browser
```

## The demo

Open `demo/index.html`. It has **two typing experiences** to compare:

- **Mode A — QWERTY + live conversion:** you see a normal English keyboard, type `saxlshi`, Georgian candidates appear in the suggestion bar, space commits the top one. Backspace right after a commit undoes the autocorrect.
- **Mode B — Georgian letters:** standard Georgian layout on the keys, with completions/spellcheck in the suggestion bar.

A hardware keyboard works in both modes.

## Roadmap to the real iOS keyboard

1. Port `engine/translit.js` to a Swift package (pure logic, unit-testable; trie can be a precompiled binary blob for fast cold-start — keyboard extensions have tight memory/launch budgets).
2. Xcode project: App target (onboarding, settings, personal dictionary) + **Custom Keyboard Extension** target (`com.apple.product-type.app-extension` with `NSExtensionPointIdentifier = com.apple.keyboard-service`). *Not* an iMessage/Messages extension.
3. App Group for shared user dictionary (SQLite) between app and extension.
4. Learning: promote repeatedly-typed unknown words into the user lexicon; personal bigram counts for better predictions.
5. Better corpus: rebuild frequency list from Georgian Wikipedia + web corpus (Crúbadán is good but dated); consider hunspell ka_GE (143k forms) for spellcheck coverage.
6. Ship: TestFlight with Georgian community feedback loop.

## Data licenses

- Word/bigram frequencies: [Crúbadán](http://crubadan.org/) by Kevin Scannell — CC-BY 4.0 (via [GeoWordsDatabase](https://github.com/bumbeishvili/GeoWordsDatabase), MIT).
- The engine and app code: MIT.

## Legacy reference

`docs/AGENT-TASKS.md`, `docs/ARCHITECTURE.md`, `engine/GeorgianIME/`, `ios/`, `layouts/`, and the `geo-keyboard/` Xcode project are the earlier scaffold, kept for reference. Note: that Xcode project is a Messages extension (wrong target type for a keyboard) — the real app will use a Custom Keyboard Extension target.
