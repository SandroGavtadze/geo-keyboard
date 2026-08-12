# Building the iOS keyboard

Everything below happens on your Mac. Total time first run: ~15 minutes.

## 1. Verify the engine (recommended first step)

```bash
cd ios-app/GeoIME
swift test
```

This runs the same 82-phrase suite as the JS engine (`node engine/test.js`).
Expected: all tests pass — top-1 ≥ 80/82, top-3 82/82, latency well under budget.
If a test fails, stop and report the failure output back to Claude before continuing.

## 2. Generate the Xcode project

```bash
brew install xcodegen        # once
cd ios-app
xcodegen generate
open GeoKeyboard.xcodeproj
```

(If you'd rather not install XcodeGen, see "Manual project setup" at the bottom.)

## 3. Signing & App Group (one-time, in Xcode)

1. Select the project → **GeoKeyboard** target → *Signing & Capabilities* → pick your **Team**.
2. Do the same for the **GeoKeyboardExt** target.
3. Both targets already declare App Group `group.com.sandrogavtadze.geokeyboard`.
   Xcode will offer to register it — accept. If the group ID is taken, change it in
   **both** entitlements files *and* in `GeoKeyboard/Shared/AppSettings.swift`.

## 4. Run it

1. Select the **GeoKeyboard** scheme, choose your iPhone (plugged in or on the same Wi-Fi), press **▶**.
2. On the phone: Settings → General → Keyboard → Keyboards → **Add New Keyboard…** → GeoKeyboard.
3. In any app, hold the 🌐 key and pick **ქართული · GeoKeyboard**.
4. Type `saxlshi xar`, press space — you should see **სახლში ხარ**.

Do **not** enable Full Access — the keyboard doesn't need or ask for it.

## What to test on device

- Typing feel + suggestion latency (should feel instant; engine is ~0.04 ms/query).
- Space commits the top candidate; backspace right after undoes it.
- აბგ/abc key flips layouts; the default comes from the app's Settings tab.
- Next-word predictions appear after a committed word.
- Works in Messages, Notes, Safari, WhatsApp.

## Manual project setup (no XcodeGen)

1. Xcode → New Project → iOS App → name `GeoKeyboard`, SwiftUI. Delete the generated ContentView/App files.
2. File → New → Target → **Custom Keyboard Extension** (⚠️ NOT "iMessage Extension") → name `GeoKeyboardExt`.
3. File → Add Package Dependencies → Add Local… → select `ios-app/GeoIME`. Add the `GeoIME` library to **both** targets.
4. Drag `GeoKeyboard/HostApp/*.swift` + `GeoKeyboard/Shared/*.swift` into the app target;
   `GeoKeyboard/KeyboardExtension/*.swift` + `GeoKeyboard/Shared/*.swift` into the extension target.
5. Delete the template `KeyboardViewController.swift` Xcode created (ours replaces it).
6. Add the App Group capability to both targets (`group.com.sandrogavtadze.geokeyboard`).
7. In the extension's Info.plist confirm `NSExtensionPointIdentifier` = `com.apple.keyboard-service`.

## Troubleshooting

- **Keyboard doesn't appear in Settings** → the extension didn't install; make sure the app target *embeds* the extension (Frameworks & Extensions phase) and re-run.
- **Keys show but no suggestions** → dictionary resources missing; check GeoIME package resources built into the extension.
- **"No such module GeoIME"** → the package wasn't added to that target's dependencies.
