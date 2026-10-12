import Foundation

/// Settings shared between the host app and the keyboard extension via App Group.
public enum AppSettings {

    /// ⚠️ Must match the App Group enabled on BOTH targets in Signing & Capabilities.
    public static let appGroupID = "group.com.sandrogavtadze.geokeyboard"

    public enum KeyboardMode: String, CaseIterable, Identifiable {
        case latin      // Mode A: QWERTY + live Latin→Georgian conversion (default)
        case georgian   // Mode B: Georgian letters on keys

        public var id: String { rawValue }
        public var displayName: String {
            switch self {
            case .latin: return "QWERTY + ცოცხალი გადაყვანა"
            case .georgian: return "ქართული ასოები"
            }
        }
    }

    /// Non-consumable IAP product ID (App Store Connect + GeoKeyboard.storekit).
    public static let proProductID = "com.sandrogavtadze.GeoKeyboard.pro"

    /// Which features require the Pro unlock. Flip a flag to change scope;
    /// core typing (conversion, autocorrect, candidates) is always free.
    public enum ProGate {
        public static let nextWordPrediction = true
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    private static let modeKey = "defaultKeyboardMode"
    private static let autocorrectKey = "autocorrectEnabled"
    private static let proUnlockedKey = "isProUnlocked"

    public static var defaultMode: KeyboardMode {
        get { KeyboardMode(rawValue: defaults.string(forKey: modeKey) ?? "") ?? .latin }
        set { defaults.set(newValue.rawValue, forKey: modeKey) }
    }

    /// When on (default), space commits the top Georgian candidate in Latin mode.
    public static var autocorrectEnabled: Bool {
        get { defaults.object(forKey: autocorrectKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: autocorrectKey) }
    }

    /// Cached Pro entitlement. Written only by the host app (ProStore) after
    /// StoreKit verification; the extension just reads it.
    public static var isProUnlocked: Bool {
        get { defaults.bool(forKey: proUnlockedKey) }
        set { defaults.set(newValue, forKey: proUnlockedKey) }
    }

    public static var nextWordPredictionEnabled: Bool {
        !ProGate.nextWordPrediction || isProUnlocked
    }
}
