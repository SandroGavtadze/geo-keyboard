import UIKit
import SwiftUI
import GeorgianIME

final class KeyboardViewController: UIInputViewController {
    private let tokenizer = Tokenizer()

    private lazy var engine: SuggestionEngine = {
        let lex = Lexicon()
        lex.loadBundledWordList()

        let storePath = AppGroup.sqlitePath()
        let sqlite = try? SQLiteStore(path: storePath)
        let userStore = UserLexiconStore(store: sqlite ?? (try! SQLiteStore(path: storePath)))
        let gen = CandidateGenerator()
        return SuggestionEngine(lexicon: lex, generator: gen, userStore: userStore)
    }()

    private var hosting: UIHostingController<KeyboardRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        let root = KeyboardRootView(
            onKey: { [weak self] action in self?.handle(action: action) },
            fetchSuggestions: { [weak self] in self?.currentSuggestions() ?? [] },
            onAcceptSuggestion: { [weak self] s in self?.acceptSuggestion(s) }
        )
        let host = UIHostingController(rootView: root)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
        hosting = host
    }

    private func handle(action: KeyAction) {
        let proxy = textDocumentProxy

        switch action {
        case .insert(let text):
            proxy.insertText(text)
        case .backspace:
            proxy.deleteBackward()
        case .space:
            proxy.insertText(" ")
        case .returnKey:
            proxy.insertText("\n")
        case .nextKeyboard:
            advanceToNextInputMode()
        case .noop:
            break
        }

        // Trigger SwiftUI refresh
        hosting?.rootView = hosting?.rootView ?? KeyboardRootView(
            onKey: { [weak self] a in self?.handle(action: a) },
            fetchSuggestions: { [weak self] in self?.currentSuggestions() ?? [] },
            onAcceptSuggestion: { [weak self] s in self?.acceptSuggestion(s) }
        )
    }

    private func currentSuggestions() -> [Suggestion] {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let ctx = tokenizer.extract(fromBeforeCaret: before)
        return engine.suggest(token: ctx.currentToken, prevToken: ctx.prevToken, max: 3)
    }

    private func acceptSuggestion(_ suggestion: Suggestion) {
        let proxy = textDocumentProxy
        let before = proxy.documentContextBeforeInput ?? ""
        let ctx = tokenizer.extract(fromBeforeCaret: before)
        let current = ctx.currentToken

        // Replace current token if suggestion differs.
        if !current.isEmpty && suggestion.text != current {
            for _ in 0..<current.count { proxy.deleteBackward() }
            proxy.insertText(suggestion.text)
        }

        // Learn accepted suggestion when user taps it (even if verbatim).
        if !suggestion.text.isEmpty {
            engine.learnAccepted(word: suggestion.text, prevToken: ctx.prevToken)
        }
    }
}
