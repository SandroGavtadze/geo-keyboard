# Georgian Keyboard + Spell Checker (iOS) — Starter Scaffold

This repository contains an on-device Georgian custom keyboard design (layout-matching the referenced app)
and a language engine scaffold (spell-check + learning) intended to be wired into an iOS Keyboard Extension.

## What’s included
- `docs/ARCHITECTURE.md` — architecture decisions and constraints
- `docs/AGENT-TASKS.md` — an execution checklist for an AI agent / developer
- `layouts/ka_letters.json` — Georgian letters layout matching the screenshot
- `layouts/ka_numbers.json` / `layouts/ka_symbols.json` — placeholders to be filled to match the app
- `engine/` — Swift Package scaffold for tokenization, suggestions, lexicon, SQLite persistence
- `ios/` — file templates for the Keyboard Extension and Host App (SwiftUI)

## How to use
1. In Xcode: create a new iOS App project (SwiftUI).
2. Add a **Keyboard Extension** target to the project.
3. Add the `engine/GeorgianIME` Swift Package (local package).
4. Enable an **App Group** for both targets (Host App + Keyboard Extension).
5. Copy the templates from `ios/` into the corresponding targets and wire imports.

See `docs/AGENT-TASKS.md` for the concrete steps and acceptance criteria.
# GeorgianKeyboardIME
