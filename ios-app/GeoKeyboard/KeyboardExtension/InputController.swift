import Foundation
import UIKit
import GeoIME

/// Bridges the SwiftUI keyboard UI to UIKit's text document proxy and the GeoIME engine.
///
/// Strategy (Mode A / Latin) — pinyin-style composition with marked text:
/// as the user types Latin letters we keep them in an internal buffer
/// (`composedLatin`) and display the BEST GEORGIAN CANDIDATE at the caret as
/// marked (underlined) text. Space or a suggestion tap commits the Georgian
/// word into the document. Backspace right after a commit undoes it and
/// restores the Latin composition.
///
/// Why an internal buffer: documentContextBeforeInput updates ASYNCHRONOUSLY
/// after insertText, so reading it back immediately returns stale text (it
/// dropped the first letter of "saxlshi" in testing). The buffer is the source
/// of truth; we only reconcile with the proxy when we're not composing.
final class InputController: ObservableObject {

    @Published var mode: AppSettings.KeyboardMode = AppSettings.defaultMode
    @Published var suggestions: [Suggestion] = []
    @Published var shiftOn = false
    @Published var engineReady = false

    weak var viewController: UIInputViewController?

    private var engine: Engine?
    /// Last commit, for backspace-undo: (latin the user typed, georgian we inserted)
    private var lastCommit: (latin: String, georgian: String)?
    /// The Latin letters of the word currently being composed (Mode A).
    private var composedLatin = ""

    init() {
        // Dictionary parse is ~100–300 ms; never block keyboard appearance.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let engine = Engine.loadBundled()
            DispatchQueue.main.async {
                self?.engine = engine
                self?.engineReady = true
                self?.refreshSuggestions()
                self?.updateMarkedText()
            }
        }
    }

    private var proxy: UITextDocumentProxy? { viewController?.textDocumentProxy }

    // MARK: - Token extraction

    /// Trailing Latin token before the caret as the proxy sees it (may lag).
    private var proxyLatinToken: String {
        let before = proxy?.documentContextBeforeInput ?? ""
        return String(before.reversed().prefix(while: { $0.isASCII && $0.isLetter }).reversed())
    }

    /// Trailing Georgian token before the caret (Mode B composing word).
    private var currentGeorgianToken: String {
        let before = proxy?.documentContextBeforeInput ?? ""
        return String(before.reversed().prefix(while: { ("ა"..."ჰ").contains($0) }).reversed())
    }

    private var currentToken: String {
        mode == .latin ? composedLatin : currentGeorgianToken
    }

    /// Previous committed Georgian word (for bigram next-word predictions).
    private var previousWord: String? {
        let before = proxy?.documentContextBeforeInput ?? ""
        let stripped = mode == .georgian ? before.dropLast(currentGeorgianToken.count) : before[...]
        let words = stripped.split(whereSeparator: { !("ა"..."ჰ").contains($0) })
        return words.last.map(String.init)
    }

    /// Best committable Georgian text for the current composition.
    private var topCandidate: String {
        if let s = suggestions.first(where: { $0.kind != .prediction }) { return s.text }
        if let engine { return engine.literal(composedLatin) }
        return composedLatin
    }

    // MARK: - Key handling

    func insert(_ text: String) {
        var t = text
        if shiftOn { t = t.uppercased(); shiftOn = false }
        lastCommit = nil
        if mode == .latin, t.allSatisfy({ $0.isASCII && $0.isLetter }) {
            composedLatin += t
            refreshSuggestions()
            updateMarkedText()
        } else {
            // Punctuation/digit while composing: commit the word first.
            commitCompositionIfNeeded()
            proxy?.insertText(t)
            refreshSuggestions()
        }
    }

    func insertGeorgian(_ ch: String, shifted: String?) {
        let t = (shiftOn ? shifted : nil) ?? ch
        shiftOn = false
        proxy?.insertText(t)
        lastCommit = nil
        refreshSuggestions()
    }

    func space() {
        guard let proxy else { return }
        if mode == .latin, !composedLatin.isEmpty {
            let text = AppSettings.autocorrectEnabled ? topCandidate : (engine?.literal(composedLatin) ?? composedLatin)
            let latin = composedLatin
            composedLatin = ""
            proxy.insertText(text)   // replaces the marked text
            proxy.insertText(" ")
            lastCommit = (latin: latin, georgian: text)
        } else {
            proxy.insertText(" ")
            lastCommit = nil
        }
        refreshSuggestions()
    }

    func backspace() {
        guard let proxy else { return }
        if mode == .latin, !composedLatin.isEmpty {
            composedLatin.removeLast()
            refreshSuggestions()
            updateMarkedText()
            return
        }
        // Undo auto-commit: " " + georgian → restore latin composition
        if let commit = lastCommit,
           (proxy.documentContextBeforeInput ?? "").hasSuffix(commit.georgian + " ") {
            for _ in 0..<(commit.georgian.count + 1) { proxy.deleteBackward() }
            lastCommit = nil
            if mode == .latin {
                composedLatin = commit.latin
                refreshSuggestions()
                updateMarkedText()
                return
            }
        } else {
            proxy.deleteBackward()
            lastCommit = nil
        }
        refreshSuggestions()
    }

    func returnKey() {
        commitCompositionIfNeeded()
        proxy?.insertText("\n")
        lastCommit = nil
        refreshSuggestions()
    }

    func accept(_ suggestion: Suggestion) {
        guard let proxy else { return }
        if suggestion.kind == .prediction {
            proxy.insertText(suggestion.text + " ")
        } else if mode == .latin {
            let latin = composedLatin
            composedLatin = ""
            proxy.insertText(suggestion.text)   // replaces the marked text
            proxy.insertText(" ")
            if !latin.isEmpty { lastCommit = (latin: latin, georgian: suggestion.text) }
        } else {
            let token = currentGeorgianToken
            for _ in 0..<token.count { proxy.deleteBackward() }
            proxy.insertText(suggestion.text + " ")
        }
        refreshSuggestions()
    }

    func toggleMode() {
        commitCompositionIfNeeded()
        mode = mode == .latin ? .georgian : .latin
        refreshSuggestions()
    }

    func toggleShift() { shiftOn.toggle() }

    /// Called from textDidChange (caret moved, field switched, external edit).
    /// While composing we own the state — but if our composing preview is no
    /// longer at the caret (field cleared via ⓧ, caret moved, external edit),
    /// the composition is stale and must be dropped.
    func reconcileWithProxy() {
        if composedLatin.isEmpty { refreshSuggestions(); return }
        let before = proxy?.documentContextBeforeInput ?? ""
        let preview = topCandidate
        if before.isEmpty || !before.hasSuffix(preview) {
            composedLatin = ""
            refreshSuggestions()
        }
    }

    // MARK: - Internals

    /// Shows the best Georgian candidate at the caret as underlined marked text.
    private func updateMarkedText() {
        guard let proxy, mode == .latin else { return }
        if composedLatin.isEmpty {
            proxy.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
            proxy.unmarkText()
        } else {
            let preview = topCandidate
            proxy.setMarkedText(preview, selectedRange: NSRange(location: (preview as NSString).length, length: 0))
        }
    }

    private func commitCompositionIfNeeded() {
        guard mode == .latin, !composedLatin.isEmpty, let proxy else { return }
        let text = topCandidate
        let latin = composedLatin
        composedLatin = ""
        proxy.insertText(text)
        lastCommit = (latin: latin, georgian: text)
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
