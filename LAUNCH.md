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

### Test the Pro purchase without App Store Connect

The GeoKeyboard scheme uses `ios-app/GeoKeyboard.storekit`. Run in the Simulator → Pro tab → Unlock Pro. Predictions should then appear in the suggestion bar after each committed word. Reset with Xcode → Debug → StoreKit → Manage Transactions → delete the transaction (predictions disappear after the app is reopened).

What Pro gates is one flag: `AppSettings.ProGate.nextWordPrediction` in `ios-app/GeoKeyboard/Shared/AppSettings.swift`.

## 2. Developer portal — identifiers

[developer.apple.com/account](https://developer.apple.com/account) → Certificates, IDs & Profiles → Identifiers. (Xcode's automatic signing usually creates these on first device build; verify they exist.)

1. App Group: `group.com.sandrogavtadze.geokeyboard`
2. App ID `com.sandrogavtadze.GeoKeyboard` — capabilities: App Groups (assign the group), In-App Purchase
3. App ID `com.sandrogavtadze.GeoKeyboard.keyboard` — capabilities: App Groups (assign the group)

## 3. Agreements, Tax, and Banking

[App Store Connect](https://appstoreconnect.apple.com) → Business. Sign the **Paid Apps** agreement and complete tax + banking. The IAP will not load (even in TestFlight) until this shows Active.

## 4. Create the app record

App Store Connect → Apps → + → New App: platform iOS, name / language / bundle ID / SKU from `store/listing.md`.

Then fill in:
- **App Information:** category, age rating, Privacy Policy URL
- **Pricing and Availability:** Free, all territories
- **App Privacy:** “Data Not Collected”
- **Version 1.0 page:** promotional text, description, keywords, support + marketing URLs — EN, then add Georgian localization

## 5. Create the in-app purchase

App → Monetization → In-App Purchases → + → Non-Consumable. Product ID `com.sandrogavtadze.GeoKeyboard.pro`; price, EN/KA display name and description, review note and review screenshot per `store/listing.md`. Status must reach **Ready to Submit**.

## 6. Privacy page

Pushed to `main` under `docs/`, so GitHub Pages serves it at
https://sandrogavtadze.github.io/geo-keyboard/privacy.html — open it and confirm it loads before submitting.

## 7. Screenshots

Shot list and sizes are in `store/listing.md`. Capture in Simulator on a 6.9" and a 6.5" device (⌘S), upload under the version's Previews and Screenshots for both languages.

## 8. Archive and TestFlight

1. Xcode: destination **Any iOS Device (arm64)** → Product → Archive.
2. Organizer → Distribute App → App Store Connect → Upload.
3. When processing finishes: TestFlight → answer export compliance (already declared `ITSAppUsesNonExemptEncryption = false`) → create an External group → add build → enable the **public link** and share with friends for a few days. External testing needs a short Beta App Review.
4. Verify on TestFlight: keyboard installs, conversion works, Pro purchase works in sandbox (free), Restore works.

For each later upload bump `CURRENT_PROJECT_VERSION` in `ios-app/project.yml` and re-run `xcodegen generate`.

## 9. Submit for review

Version page → select the build → **In-App Purchases and Subscriptions** → attach GeoKeyboard Pro (the first IAP must be submitted together with an app version) → paste App Review notes → Add for Review → Submit.

## Common rejections for keyboards

- **Keyboard missing a next-keyboard (globe) key on devices without one in the system bar** — ours shows it; verify on a Home-button device/simulator.
- **App is only a keyboard with no host-app functionality** — the host app has onboarding, settings and the Pro screen; that is sufficient.
- **IAP not found during review** — the IAP wasn't attached to the version, or the Paid Apps agreement isn't active.
- **Missing Restore Purchases** — it's on the Pro tab.
