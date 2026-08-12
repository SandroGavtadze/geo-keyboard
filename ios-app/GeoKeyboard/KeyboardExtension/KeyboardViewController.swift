import UIKit
import SwiftUI

/// Principal class of the keyboard extension (see Info.plist → NSExtensionPrincipalClass).
final class KeyboardViewController: UIInputViewController {

    private let controller = InputController()
    private var hosting: UIHostingController<KeyboardView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        controller.viewController = self

        let host = UIHostingController(rootView: KeyboardView(controller: controller))
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
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

        // Keyboard height: keys (3×42 + spacing) + suggestion bar.
        let height = view.heightAnchor.constraint(equalToConstant: 248)
        height.priority = .defaultHigh
        height.isActive = true
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // Caret moved, field switched, or external edit — recompute suggestions.
        controller.refreshSuggestions()
    }
}
