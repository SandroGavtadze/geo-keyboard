# App Store listing — Kartulad

Copy-paste source for App Store Connect. Character limits in parentheses.

## Identifiers

| | |
|---|---|
| App bundle ID | `com.sandrogavtadze.GeoKeyboard.keyboard` (the App Store Connect record is bound to this ID) |
| Keyboard extension bundle ID | `com.sandrogavtadze.GeoKeyboard.keyboard.ext` |
| App Group | `group.com.sandrogavtadze.geokeyboard` |
| SKU | `geokeyboard-ios` |
| Primary language | English (U.S.) — the App Store has no Georgian localization, so the Georgian text goes in the same description |
| Category | Utilities (secondary: Productivity) |
| Age rating | 4+ |
| Price | Free (no in-app purchases) |
| Privacy Policy URL | https://sandrogavtadze.github.io/geo-keyboard/privacy.html |
| Support URL | https://github.com/SandroGavtadze/geo-keyboard/issues |
| Marketing URL | https://sandrogavtadze.github.io/geo-keyboard/ (optional; this is the web prototype) |
| Copyright | `2026 Alexandre Gavtadze` (no © symbol) |

## Listing (English U.S.)

**Name (30):** Kartulad: QWERTY to Georgian

The name field only accepts Latin characters — Georgian script and "→" are rejected.

**Subtitle (30):** Phonetic keyboard, autocorrect

> **App Store Connect only accepts Latin text here.** Georgian script is rejected in the name, promotional text and description, and so are some symbols (the → arrow, and possibly bullets, curly quotes and long dashes). The text below uses plain keyboard punctuation only. The English-only description and promotional text have passed validation; the Latin-only keywords haven't been confirmed yet.

**Promotional text (170):**
Type Georgian the way you already text it - in Latin letters. Kartulad converts as you go, with autocorrect and next-word predictions.

**Description (4000):**
Kartulad lets you write Georgian without hunting for letters. Type phonetically on the QWERTY layout you already know and the keyboard turns it into proper Georgian script as you type.

Type "saxlshi xar?" and get it in Georgian script.
Type "gamarjoba, rogor xar" and get it in Georgian script.

Made for Georgians abroad, and for anyone whose thumbs learned QWERTY first.

HOW IT WORKS
- Type in Latin letters - see Georgian appear live, underlined, as you go
- Press space to accept the top suggestion, or tap another candidate
- Backspace right after a correction undoes it
- Prefer real Georgian keys? Switch layouts any time with one key
- Full number and symbol layers

SMART, NOT GUESSY
- Autocorrect built on a 49,000-word Georgian frequency dictionary
- Next-word predictions after each word
- Handles ambiguous spellings by picking the real word
- Works in every app: Messages, WhatsApp, Telegram, Mail, Notes

PRIVATE BY DESIGN
- Does NOT ask for "Allow Full Access"
- No network access, no accounts, no analytics, no ads
- Nothing you type ever leaves your iPhone

FREE
Everything is free: typing, live conversion, autocorrect and next-word predictions. No ads, no subscription, no in-app purchases.

**Keywords (100):**
kartuli,qartuli,translit,transliteration,latin,georgia,tbilisi,sakartvelo,klaviatura,ime,mkhedruli

**What's New (first version):** Initial release.

## App Privacy (nutrition label)

Data collection: **No, we do not collect data from this app.**

## App Review notes

Plain ASCII only, in case the Notes field rejects Georgian script like the other fields.

```text
Kartulad is a custom keyboard extension for typing Georgian phonetically in Latin letters.

To test:
1. Launch the app, then go to Settings > General > Keyboard > Keyboards > Add New Keyboard... > Kartulad.
2. Open Notes or Messages, hold the globe key and select the keyboard whose name ends in "Kartulad" (the first word of its name is Georgian).
3. Type "saxlshi xar" - it converts live into Georgian script ("at home?"). Space accepts the top candidate.
4. The key to the right of "123" (labelled with three Georgian letters) switches between Latin-conversion mode and direct Georgian letters; "123" opens numbers and symbols.
5. After a word is committed, next-word predictions appear in the bar above the keys.

The keyboard does NOT request Full Access (RequestsOpenAccess = false) and makes no network requests. No account or login is needed.

The app is free and has no in-app purchases.
```

## Screenshots

Files are in `store/screenshots/`, same five shots in each folder:

| Folder | Size | App Store Connect slot |
|---|---|---|
| `6.3/` | 1206 × 2622 | iPhone with Dynamic Island (medium display) — **required** |
| `6.9/` | 1320 × 2868 | iPhone with Dynamic Island (large display) — optional |
| `6.5/` | 1284 × 2778 | iPhone with Face ID (large display) — optional |

`6.9/` are the original simulator captures; the other two are scaled from them.

1. **Messages, mid-word** — `saxlshi` typed, marked text + suggestion bar showing სახლში. Caption: “Type Latin. Get ქართული.”
2. **Messages, finished sentence** — “გამარჯობა, როგორ ხარ?” sent as a bubble, keyboard visible. Caption: “Converts as you type.”
3. **Georgian-letters layout** — after tapping აბგ. Caption: “Or tap real Georgian keys.”
4. **Next-word predictions** — a word committed, three predictions in the bar. Caption: “Predicts your next word.”
5. **App Settings/Onboarding screen** — “Full Access არ არის საჭირო” visible. Caption: “Private. No Full Access. No network.”

Simulator tips: confirm our keyboard is active by the suggestion bar + აბგ + 123 keys; never type during “Installing…”; if it wedges, quit Simulator and re-run. Capture with ⌘S in Simulator.

## Georgian copy (not accepted by App Store Connect)

Kept for the website, social posts or a future store that accepts Georgian.

Kartulad-ით ქართულად წერა აღარ მოითხოვს ასოების ძებნას. აკრიფე ლათინურად, ნაცნობ QWERTY განლაგებაზე, და კლავიატურა წერის პროცესშივე გადაიყვანს ტექსტს ქართულ დამწერლობაზე.

saxlshi xar? → სახლში ხარ?
gamarjoba, rogor xar → გამარჯობა, როგორ ხარ

შექმნილია საზღვარგარეთ მცხოვრები ქართველებისთვის და ყველასთვის, ვინც ლათინურით წერას არის მიჩვეული.

როგორ მუშაობს
• წერე ლათინურად — ქართული ტექსტი მაშინვე ჩნდება
• Space ადასტურებს პირველ ვარიანტს; შეგიძლია სხვა ვარიანტსაც დააჭირო
• Backspace შესწორებისთანავე აბრუნებს მას უკან
• გირჩევნია ქართული ასოები? აბგ / abc ღილაკით ნებისმიერ დროს გადართავ
• ციფრებისა და სიმბოლოების სრული განლაგება

ჭკვიანი ავტოკორექცია
• 49 000 სიტყვიანი ქართული სიხშირული ლექსიკონი
• შემდეგი სიტყვის შეთავაზება ყოველი სიტყვის შემდეგ
• არჩევს სწორ სიტყვას ორაზროვან შემთხვევებში (t/ტ/თ, k/კ/ქ, p/პ/ფ, c/ც/წ…)
• მუშაობს ყველა აპში

კონფიდენციალურობა
• არ ითხოვს „სრულ წვდომას“
• ინტერნეტის, ანგარიშის, ანალიტიკისა და რეკლამის გარეშე
• რასაც წერ, შენს iPhone-ს არ ტოვებს

უფასო
ყველაფერი უფასოა: წერა, ცოცხალი გადაყვანა, ავტოკორექცია და შემდეგი სიტყვის შეთავაზება. რეკლამის, გამოწერისა და აპშიდა შენაძენების გარეშე.
