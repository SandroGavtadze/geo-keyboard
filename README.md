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

## The iOS app (`ios-app/`)

The Swift port lives in `ios-app/`:

```
ios-app/GeoIME/          Swift package: engine port + bundled dictionary + 82-case test suite
ios-app/GeoKeyboard/     Host app (onboarding, settings) + Custom Keyboard Extension sources
ios-app/project.yml      XcodeGen spec (correct keyboard-service extension target)
ios-app/SETUP.md         ⭐ step-by-step build & install guide
```

Both typing modes ship: users pick a default in the app's Settings and can flip
anytime with the აბგ/abc key on the keyboard. Start with `ios-app/SETUP.md`.

## Roadmap

1. ~~Port engine to Swift package~~ ✅ (`ios-app/GeoIME`, verify with `swift test` on a Mac)
2. ~~Xcode project with **Custom Keyboard Extension** target~~ ✅ (`ios-app/project.yml` — *not* an iMessage extension)
3. On-device learning: promote repeatedly-typed unknown words into a user lexicon (SQLite in the App Group); personal bigram counts.
4. Better corpus: conversational sources so chat words outrank literary ones; consider hunspell ka_GE (143k forms) for spellcheck coverage.
5. Precompiled binary trie for faster cold-start if TSV parse feels slow on older devices.
6. Ship: TestFlight with Georgian community feedback loop.

## Data licenses

- Word/bigram frequencies: [Crúbadán](http://crubadan.org/) by Kevin Scannell — CC-BY 4.0 (via [GeoWordsDatabase](https://github.com/bumbeishvili/GeoWordsDatabase), MIT).
- The engine and app code: MIT.

## Legacy reference

`docs/AGENT-TASKS.md`, `docs/ARCHITECTURE.md`, `engine/GeorgianIME/`, `ios/`, `layouts/`, and the `geo-keyboard/` Xcode project are the earlier scaffold, kept for reference. Note: that Xcode project is a Messages extension (wrong target type for a keyboard) — the real app will use a Custom Keyboard Extension target.
