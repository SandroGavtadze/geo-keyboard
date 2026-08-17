import SwiftUI
import GeoIME

/// Which key plane is showing.
enum KeyLayer { case letters, numbers, symbols }

/// The full keyboard UI: suggestion bar + key rows for both modes and all layers.
struct KeyboardView: View {
    @ObservedObject var controller: InputController
    @State private var layer: KeyLayer = .letters

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
    private let numberRows: [[String]] = [
        ["1","2","3","4","5","6","7","8","9","0"],
        ["-","/",":",";","(",")","₾","&","@","\""],
        [".",",","?","!","'"],
    ]
    private let symbolRows: [[String]] = [
        ["[","]","{","}","#","%","^","*","+","="],
        ["_","\\","|","~","<",">","€","$","£","•"],
        [".",",","?","!","'"],
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

    @ViewBuilder
    private var keyRows: some View {
        switch layer {
        case .letters: letterLayer
        case .numbers: punctLayer(rows: numberRows, subToggleLabel: "#+=", subToggleTarget: .symbols)
        case .symbols: punctLayer(rows: symbolRows, subToggleLabel: "123", subToggleTarget: .numbers)
        }
    }

    private var letterLayer: some View {
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
                specialKey("123", width: 42) { layer = .numbers }
                specialKey(controller.mode == .latin ? "აბგ" : "abc", width: 46) { controller.toggleMode() }
                globeKey
                spaceKey
                specialKey("⏎", width: 56) { controller.returnKey() }
            }
        }
    }

    /// Numbers / symbols plane. Typing any of these keys commits the pending
    /// Georgian composition first (handled inside controller.insert).
    private func punctLayer(rows: [[String]], subToggleLabel: String, subToggleTarget: KeyLayer) -> some View {
        VStack(spacing: 7) {
            row(rows[0])
            row(rows[1])
            HStack(spacing: 5) {
                specialKey(subToggleLabel, width: 52) { layer = subToggleTarget }
                row(rows[2]).padding(.horizontal, 8)
                specialKey("⌫", width: 52) { controller.backspace() }
            }
            HStack(spacing: 5) {
                specialKey(controller.mode == .latin ? "abc" : "აბგ", width: 52) { layer = .letters }
                globeKey
                spaceKey
                specialKey("⏎", width: 56) { controller.returnKey() }
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
        let isLetterLayer = layer == .letters
        let isLatin = controller.mode == .latin
        let shifted: String = {
            guard isLetterLayer else { return k }
            return isLatin ? k.uppercased() : (georgianShift[k] ?? k)
        }()
        let label = controller.shiftOn && isLetterLayer ? shifted : k
        return Button {
            if !isLetterLayer {
                controller.insert(k)          // digits & punctuation commit composition first
            } else if isLatin {
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
