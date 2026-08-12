import SwiftUI
import GeoIME

/// The full keyboard UI: suggestion bar + key rows for both modes.
struct KeyboardView: View {
    @ObservedObject var controller: InputController

    private let latinRows: [[String]] = [
        ["q","w","e","r","t","y","u","i","o","p"],
        ["a","s","d","f","g","h","j","k","l"],
        ["z","x","c","v","b","n","m"],
    ]
    private let georgianRows: [[String]] = [
        ["ქ","წ","ე","რ","ტ","ყ","უ","ი","ო","პ"],
        ["ა","ს","დ","ფ","გ","ჰ","ჯ","კ","ლ"],
        ["ზ","ხ","ც","ვ","ბ","ნ","მ"],
    ]
    /// Shift layer for Georgian keys (aspirated/extended letters).
    private let georgianShift: [String: String] = [
        "ტ":"თ","წ":"ჭ","ზ":"ძ","ს":"შ","ც":"ჩ","ჯ":"ჟ","გ":"ღ","კ":"ქ","ხ":"ჴ","ჰ":"ჵ"
    ]

    var body: some View {
        VStack(spacing: 6) {
            suggestionBar
            keyRows
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }

    private var suggestionBar: some View {
        HStack(spacing: 6) {
            if controller.engineReady {
                ForEach(Array(controller.suggestions.prefix(4).enumerated()), id: \.offset) { i, s in
                    Button { controller.accept(s) } label: {
                        Text(s.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(i == 0 && s.kind != .prediction
                                          ? Color.accentColor.opacity(0.18)
                                          : Color(.secondarySystemBackground))
                            )
                    }
                    .buttonStyle(.plain)
                }
                if controller.suggestions.isEmpty {
                    Spacer().frame(height: 34)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity).frame(height: 34)
            }
        }
        .frame(minHeight: 38)
    }

    private var keyRows: some View {
        let rows = controller.mode == .latin ? latinRows : georgianRows
        return VStack(spacing: 7) {
            row(rows[0])
            row(rows[1]).padding(.horizontal, 16)
            HStack(spacing: 5) {
                specialKey(controller.shiftOn ? "⬆" : "⇧", width: 42) { controller.toggleShift() }
                row(rows[2])
                specialKey("⌫", width: 42) { controller.backspace() }
            }
            HStack(spacing: 5) {
                specialKey(controller.mode == .latin ? "აბგ" : "abc", width: 46) { controller.toggleMode() }
                globeKey
                spaceKey
                specialKey("⏎", width: 64) { controller.returnKey() }
            }
        }
    }

    private func row(_ keys: [String]) -> some View {
        HStack(spacing: 5) {
            ForEach(keys, id: \.self) { k in
                keyButton(k)
            }
        }
    }

    private func keyButton(_ k: String) -> some View {
        let isLatin = controller.mode == .latin
        let shifted = isLatin ? k.uppercased() : (georgianShift[k] ?? k)
        let label = controller.shiftOn ? shifted : k
        return Button {
            if isLatin {
                controller.insert(k)
            } else {
                controller.insertGeorgian(k, shifted: georgianShift[k])
            }
        } label: {
            Text(label)
                .font(.system(size: 21))
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(.systemBackground)))
                .shadow(color: .black.opacity(0.25), radius: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func specialKey(_ label: String, width: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15))
                .frame(width: width, height: 42)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
    }

    private var globeKey: some View {
        // Next-keyboard key; UIKit requires the actual UIButton selector, so we
        // ask the view controller to advance.
        Button {
            controller.viewController?.advanceToNextInputMode()
        } label: {
            Image(systemName: "globe")
                .frame(width: 42, height: 42)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
    }

    private var spaceKey: some View {
        Button { controller.space() } label: {
            Text(controller.mode == .latin ? "space" : "სივრცე")
                .font(.system(size: 14))
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(.systemBackground)))
        }
        .buttonStyle(.plain)
    }
}
