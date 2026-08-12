import Foundation
import UIKit
import GeoIME

/// Bridges the SwiftUI keyboard UI to UIKit's text document proxy and the GeoIME engine.
///
/// Strategy (Mode A / Latin): the user's Latin letters are inserted into the
/// document as typed, so they always see what they wrote. On space (or a
/// suggestion tap) the current Latin token is replaced with the chosen Georgian
/// word. Backspace immediately after an auto-commit undoes it and restores the
/// Latin text — mirroring iOS autocorrect behavior and the web prototype.
final class InputController: ObservableObject {

    @Published var mode: AppSettings.KeyboardMode = AppSettings.defaultMode
    @Published var suggestions: [Suggestion] = []
    @Published var shiftOn = false
    @Published var engineReady = false

    weak var viewController: UIInputViewController?

    private var engine: Engine?
    /// Last auto-commit, for backspace-undo: (latin the user typed, georgian we inserted)
    private var lastCommit: (latin: String, georgian: String)?

    init() {
        // Dictionary parse is ~100–300 ms; never block keyboard appearance.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let engine = Engine.loadBundled()
            DispatchQueue.main.async {
                self?.engine = engine
                self?.engineReady = true
                self?.refreshSuggestions()
            }
        }
    }

    private var proxy: UITextDocumentProxy? { viewController?.textDocumentProxy }

    // MARK: - Token extraction

    /// Trailing Latin token before the caret (Mode A composing word).
    private var currentLatinToken: String {
        let before = proxy?.documentContextBeforeInput ?? ""
        return String(before.reversed().prefix(while: { $0.isASCII && $0.isLetter }).reversed())
    }

    /// Trailing Georgian token before the caret (Mode B composing word).
    private var currentGeorgianToken: String {
        let before = proxy?.documentContextBeforeInput ?? ""
        return String(before.reversed().prefix(while: { ("ა"..."ჰ").contains($0) }).reversed())
    }

    private var currentToken: String {
        mode == .latin ? currentLatinToken : currentGeorgianToken
    }

    /// Previous committed Georgian word (for bigram next-word predictions).
    private var previousWord: String? {
        let before = proxy?.documentContextBeforeInput ?? ""
        let stripped = before.dropLast(currentToken.count)
        let words = stripped.split(whereSeparator: { !("ა"..."ჰ").contains($0) })
        return words.last.map(String.init)
    }

    // MARK: - Key handling

    func insert(_ text: String) {
        var t = text
        if shiftOn { t = t.uppercased(); shiftOn = false }
        proxy?.insertText(t)
        lastCommit = nil
        refreshSuggestions()
    }

    func insertGeorgian(_ ch: String, shifted: String?) {
        let t = (shiftOn ? shifted : nil) ?? ch
        shiftOn = false
        proxy?.insertText(t)
        lastCommit = nil
        refreshSuggestions()
    }

    func space() {
        let token = currentToken
        if mode == .latin, !token.isEmpty, AppSettings.autocorrectEnabled,
           let top = suggestions.first, top.kind != .prediction, top.text != token {
            replaceCurrentToken(with: top.text)
            lastCommit = (latin: token, georgian: top.text)
        } else {
            lastCommit = nil
        }
        proxy?.insertText(" ")
        refreshSuggestions()
    }

    func backspace() {
        guard let proxy else { return }
        // Undo auto-commit: " " + georgian → restore latin
        if let commit = lastCommit,
           (proxy.documentContextBeforeInput ?? "").hasSuffix(commit.georgian + " ") {
            for _ in 0..<(commit.georgian.count + 1) { proxy.deleteBackward() }
            proxy.insertText(commit.latin)
            lastCommit = nil
        } else {
            proxy.deleteBackward()
            lastCommit = nil
        }
        refreshSuggestions()
    }

    func returnKey() {
        proxy?.insertText("\n")
        lastCommit = nil
        refreshSuggestions()
    }

    func accept(_ suggestion: Suggestion) {
        if suggestion.kind == .prediction {
            proxy?.insertText(suggestion.text + " ")
        } else {
            let token = currentToken
            replaceCurrentToken(with: suggestion.text)
            proxy?.insertText(" ")
            if mode == .latin, suggestion.text != token {
                lastCommit = (latin: token, georgian: suggestion.text)
            }
        }
        refreshSuggestions()
    }

    func toggleMode() {
        mode = mode == .latin ? .georgian : .latin
        refreshSuggestions()
    }

    func toggleShift() { shiftOn.toggle() }

    // MARK: - Internals

    private func replaceCurrentToken(with text: String) {
        guard let proxy else { return }
        let token = currentToken
        guard !token.isEmpty else { proxy.insertText(text); return }
        for _ in 0..<token.count { proxy.deleteBackward() }
        proxy.insertText(text)
    }

    func refreshSuggestions() {
        guard let engine else { suggestions = []; return }
        let token = currentToken
        if token.isEmpty {
            suggestions = engine.predictNext(after: previousWord, max: 3)
        } else {
            suggestions = engine.suggest(token, max: 4, prev: previousWord)
        }
    }
}
