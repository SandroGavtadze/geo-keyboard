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

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: KeyMetrics.barToKeys) {
            suggestionBar
            keyRows
        }
        .padding(.horizontal, KeyMetrics.sideInset)
        .padding(.top, 2)
        .padding(.bottom, 4)
        .environment(\.keyPalette, KeyPalette(dark: colorScheme == .dark))
    }

    // MARK: - Suggestion bar (Apple style: plain text, thin separators)

    private var suggestionBar: some View {
        let items = Array(controller.suggestions.prefix(3).enumerated())
        return HStack(spacing: 0) {
            if controller.engineReady {
                ForEach(items, id: \.offset) { i, s in
                    if i > 0 {
                        Rectangle()
                            .fill(Color.primary.opacity(0.18))
                            .frame(width: 1, height: 24)
                    }
                    Button { controller.accept(s) } label: {
                        Text(s.text)
                            .font(.system(size: 17, weight: i == 0 && s.kind != .prediction ? .semibold : .regular))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if items.isEmpty { Spacer() }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .frame(height: KeyMetrics.barHeight)
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
        return VStack(spacing: KeyMetrics.rowSpacing) {
            row(rows[0])
            GeometryReader { geo in
                // Second row is a half-key narrower on each side, like the system QWERTY.
                let keyW = (geo.size.width + KeyMetrics.keySpacing) / 10 - KeyMetrics.keySpacing
                row(rows[1]).padding(.horizontal, (keyW + KeyMetrics.keySpacing) / 2)
            }
            .frame(height: KeyMetrics.keyHeight)
            HStack(spacing: KeyMetrics.keySpacing) {
                iconKey(shiftSymbol, width: 50) { controller.toggleShift() }
                    .padding(.trailing, 6)
                row(rows[2])
                iconKey("delete.left", width: 50) { controller.backspace() }
                    .padding(.leading, 6)
            }
            bottomRow(modeLabel: controller.mode == .latin ? "აბგ" : "abc",
                      modeAction: { controller.toggleMode() })
        }
    }

    private var shiftSymbol: String { controller.shiftOn ? "shift.fill" : "shift" }

    /// Numbers / symbols plane. Typing any of these keys commits the pending
    /// Georgian composition first (handled inside controller.insert).
    private func punctLayer(rows: [[String]], subToggleLabel: String, subToggleTarget: KeyLayer) -> some View {
        VStack(spacing: KeyMetrics.rowSpacing) {
            row(rows[0])
            row(rows[1])
            HStack(spacing: KeyMetrics.keySpacing) {
                textKey(subToggleLabel, width: 50) { layer = subToggleTarget }
                row(rows[2]).padding(.horizontal, 12)
                iconKey("delete.left", width: 50) { controller.backspace() }
            }
            bottomRow(modeLabel: nil, modeAction: nil)
        }
    }

    /// 123/abc · mode toggle · (globe) · space · return
    private func bottomRow(modeLabel: String?, modeAction: (() -> Void)?) -> some View {
        HStack(spacing: KeyMetrics.keySpacing) {
            if layer == .letters {
                textKey("123", width: 48) { layer = .numbers }
            } else {
                textKey(controller.mode == .latin ? "abc" : "აბგ", width: 48) { layer = .letters }
            }
            if let modeLabel, let modeAction {
                textKey(modeLabel, width: 48, action: modeAction)
            }
            if controller.needsGlobeKey {
                iconKey("globe", width: 44) { controller.viewController?.advanceToNextInputMode() }
            }
            spaceKey
            iconKey("return.left", width: 96) { controller.returnKey() }
        }
    }

    private func row(_ keys: [String]) -> some View {
        HStack(spacing: KeyMetrics.keySpacing) {
            ForEach(keys, id: \.self) { k in
                keyButton(k)
            }
        }
    }

    // MARK: - Keys

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
                .font(.system(size: isLatin || !isLetterLayer ? 25 : 22, weight: .regular))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(KeyStyle())
    }

    private func textKey(_ label: String, width: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(KeyStyle())
        .frame(width: width)
    }

    private func iconKey(_ symbol: String, width: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .regular))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(KeyStyle())
        .frame(width: width)
    }

    /// Space bar doubles as the keyboard's identifier (like other third-party
    /// keyboards show their language here), so users can tell it's Kartulad.
    private var spaceKey: some View {
        Button { controller.space() } label: {
            HStack(spacing: 5) {
                BrandMark()
                Text("ქართულად")
                    .font(.system(size: 14, weight: .medium))
                    .opacity(0.55)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(KeyStyle())
        .accessibilityLabel("space")
    }
}

// MARK: - Look & feel

enum KeyMetrics {
    static let keyHeight: CGFloat = 45
    static let keySpacing: CGFloat = 6
    static let rowSpacing: CGFloat = 11
    static let cornerRadius: CGFloat = 8.5
    static let sideInset: CGFloat = 4
    static let barHeight: CGFloat = 40
    static let barToKeys: CGFloat = 6

    /// Total height the keyboard view needs (bar + 4 key rows + paddings).
    static let totalHeight: CGFloat = 2 + barHeight + barToKeys + keyHeight * 4 + rowSpacing * 3 + 4
}

/// Key colors tuned to match the system keyboard: translucent gray keys over
/// the system's keyboard backdrop in dark mode, white keys in light mode.
struct KeyPalette {
    let dark: Bool
    var fill: Color { dark ? Color.white.opacity(0.30) : Color.white }
    var pressed: Color { dark ? Color.white.opacity(0.55) : Color(white: 0.80) }
    var text: Color { dark ? .white : .black }
    var shadow: Color { dark ? .clear : Color.black.opacity(0.30) }
}

private struct KeyPaletteKey: EnvironmentKey {
    static let defaultValue = KeyPalette(dark: false)
}

extension EnvironmentValues {
    var keyPalette: KeyPalette {
        get { self[KeyPaletteKey.self] }
        set { self[KeyPaletteKey.self] = newValue }
    }
}

struct KeyStyle: ButtonStyle {
    @Environment(\.keyPalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(palette.text)
            .frame(height: KeyMetrics.keyHeight)
            .background(
                RoundedRectangle(cornerRadius: KeyMetrics.cornerRadius, style: .continuous)
                    .fill(configuration.isPressed ? palette.pressed : palette.fill)
                    .shadow(color: palette.shadow, radius: 0, x: 0, y: 1)
            )
            .contentShape(Rectangle())
    }
}

/// Kartulad logo mark: a tiny round Georgian flag (five-cross flag), drawn as
/// vectors so it stays crisp at space-bar size.
struct BrandMark: View {
    var size: CGFloat = 16
    private let red = Color(red: 0.86, green: 0.10, blue: 0.13)

    var body: some View {
        Canvas { ctx, sz in
            let s = sz.width
            let rect = CGRect(origin: .zero, size: sz)
            ctx.clip(to: Path(ellipseIn: rect))
            ctx.fill(Path(rect), with: .color(.white))
            // St George's cross
            let bar = s * 0.2
            ctx.fill(Path(CGRect(x: (s - bar) / 2, y: 0, width: bar, height: s)), with: .color(red))
            ctx.fill(Path(CGRect(x: 0, y: (s - bar) / 2, width: s, height: bar)), with: .color(red))
            // Four small crosses in the quadrants
            let arm = s * 0.2, thick = s * 0.08
            for cx in [s * 0.25, s * 0.75] {
                for cy in [s * 0.25, s * 0.75] {
                    ctx.fill(Path(CGRect(x: cx - arm / 2, y: cy - thick / 2, width: arm, height: thick)), with: .color(red))
                    ctx.fill(Path(CGRect(x: cx - thick / 2, y: cy - arm / 2, width: thick, height: arm)), with: .color(red))
                }
            }
            ctx.stroke(Path(ellipseIn: rect.insetBy(dx: 0.5, dy: 0.5)), with: .color(red), lineWidth: 1)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
