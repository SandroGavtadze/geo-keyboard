# Launching GeoKeyboard on the App Store

End-to-end checklist. Copy for every field lives in [store/listing.md](store/listing.md).

## 0. Prerequisites

- Xcode installed from the Mac App Store, then:
  ```bash
  sudo xcode-select -s /Applications/Xcode.app
  ```
- Paid Apple Developer Program membership (Team `DJU9LNCFNG`, set in `ios-app/project.yml`).
- `brew install xcodegen`

## 1. Build and run locally

```bash
cd ios-app
(cd GeoIME && swift test)   # 82-phrase engine suite
xcodegen generate
open GeoKeyboard.xcodeproj
```

In Xcode, for **both** targets (GeoKeyboard, GeoKeyboardExt) → Signing & Capabilities: confirm the Team and that App Groups lists `group.com.sandrogavtadze.geokeyboard`. Run on an iPhone, add the keyboard in Settings → General → Keyboard → Keyboards, and type in Messages.

## 2. Developer portal — identifiers

[developer.apple.com/account](https://developer.apple.com/account) → Certificates, IDs & Profiles → Identifiers. (Xcode's automatic signing usually creates these on first device build; verify they exist.)

1. App Group: `group.com.sandrogavtadze.geokeyboard`
2. App ID `com.sandrogavtadze.GeoKeyboard` — capabilities: App Groups (assign the group)
3. App ID `com.sandrogavtadze.GeoKeyboard.keyboard` — capabilities: App Groups (assign the group)

## 3. Agreements

The app is free with no in-app purchases, so the Paid Apps agreement, tax and banking are not required. [App Store Connect](https://appstoreconnect.apple.com) → Business only needs the Free Apps agreement, which is active by default.

## 4. Create the app record

App Store Connect → Apps → + → New App: platform iOS, name / language / bundle ID / SKU from `store/listing.md`.

Then fill in:
- **App Information:** category, age rating, Privacy Policy URL
- **Pricing and Availability:** Free, all territories
- **App Privacy:** “Data Not Collected”
- **Version 1.0 page:** promotional text, description, keywords, support + marketing URLs — EN, then add Georgian localization

## 5. Privacy page

Pushed to `main` under `docs/`, so GitHub Pages serves it at
https://sandrogavtadze.github.io/geo-keyboard/privacy.html — open it and confirm it loads before submitting.

## 6. Screenshots

Shot list and sizes are in `store/listing.md`. Capture in Simulator on a 6.9" and a 6.5" device (⌘S), upload under the version's Previews and Screenshots for both languages.

## 7. Archive and TestFlight

1. Xcode: destination **Any iOS Device (arm64)** → Product → Archive.
2. Organizer → Distribute App → App Store Connect → Upload.
3. When processing finishes: TestFlight → answer export compliance (already declared `ITSAppUsesNonExemptEncryption = false`) → create an External group → add build → enable the **public link** and share with friends for a few days. External testing needs a short Beta App Review.
4. Verify on TestFlight: keyboard installs, conversion works, predictions appear after each word.

For each later upload bump `CURRENT_PROJECT_VERSION` in `ios-app/project.yml` and re-run `xcodegen generate`.

## 8. Submit for review

Version page → select the build → paste App Review notes → Add for Review → Submit.

## Common rejections for keyboards

- **Keyboard missing a next-keyboard (globe) key on devices without one in the system bar** — ours shows it; verify on a Home-button device/simulator.
- **App is only a keyboard with no host-app functionality** — the host app has onboarding and settings; that is normally sufficient.
