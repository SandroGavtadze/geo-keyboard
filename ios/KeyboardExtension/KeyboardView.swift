import SwiftUI

struct KeyboardView: View {
    @Binding var mode: KeyboardMode
    @Binding var shiftOn: Bool
    var onKey: (KeyAction) -> Void

    // Layout data (letters are hardcoded here for now; agent should load from JSON).
    private let row1 = ["ქ","წ","ე","რ","ტ","ყ","უ","ი","ო","პ"]
    private let row2 = ["ა","ს","დ","ფ","გ","ჰ","ჯ","კ","ლ"]
    private let row3 = ["ზ","ხ","ც","ვ","ბ","ნ","მ"]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) { ForEach(row1, id:\.self) { KeyButton($0) { onKey(.insert($0)) } } }
            HStack(spacing: 6) { ForEach(row2, id:\.self) { KeyButton($0) { onKey(.insert($0)) } } }

            HStack(spacing: 6) {
                KeyButton("⇧", width: 52) { shiftOn.toggle() } // MVP: visual only
                ForEach(row3, id:\.self) { KeyButton($0) { onKey(.insert($0)) } }
                KeyButton("⌫", width: 52) { onKey(.backspace) }
            }

            HStack(spacing: 6) {
                KeyButton("123", width: 52) { mode = .numbers }
                KeyButton("🌐", width: 52) { onKey(.nextKeyboard) }
                KeyButton("😊", width: 52) { onKey(.noop) } // optional: switch to emoji keyboard not available directly
                KeyButton("ფარი", width: nil, flex: true) { onKey(.space) }
                KeyButton("შეყვანა", width: 86) { onKey(.returnKey) }
            }
        }
    }
}

struct KeyButton: View {
    let label: String
    var width: CGFloat?
    var flex: Bool = false
    var action: () -> Void

    init(_ label: String, width: CGFloat? = nil, flex: Bool = false, action: @escaping () -> Void) {
        self.label = label
        self.width = width
        self.flex = flex
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 22))
                .frame(maxWidth: flex ? .infinity : nil)
                .frame(width: width, height: 44)
                .background(Color.white)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
