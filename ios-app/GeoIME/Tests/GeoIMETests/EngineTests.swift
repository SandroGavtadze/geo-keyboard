import XCTest
@testable import GeoIME

/// Mirrors engine/test.js — same 82 phrases, same accuracy expectations.
/// JS reference results: top-1 97.6%, top-3 100%.
final class EngineTests: XCTestCase {

    static var engine: Engine!

    override class func setUp() {
        super.setUp()
        engine = Engine.loadBundled()
    }

    func testDictionaryLoaded() {
        XCTAssertGreaterThan(Self.engine.wordCount, 25_000, "bundled dictionary should load (capped at Engine.bundledWordLimit)")
        XCTAssertTrue(Self.engine.isWord("და"))
    }

    func testHeadlinePhrase() {
        let out = "saxlshi xar".split(separator: " ")
            .map { Self.engine.suggest(String($0), max: 1).first?.text ?? "" }
            .joined(separator: " ")
        XCTAssertEqual(out, "სახლში ხარ")
    }

    func testAccuracyMatchesJSReference() {
        var top1 = 0, top3 = 0
        var misses: [String] = []
        for (latin, expected) in Self.cases {
            let texts = Self.engine.suggest(latin, max: 5).map(\.text)
            if texts.first == expected { top1 += 1 }
            if texts.prefix(3).contains(expected) { top3 += 1 }
            else { misses.append("\(latin) -> wanted \(expected), got \(texts.prefix(3).joined(separator: "|"))") }
        }
        let n = Self.cases.count
        // JS reference: 80/82 top-1, 82/82 top-3. Allow 1 case of slack for
        // platform differences in tie-breaking, no more.
        XCTAssertGreaterThanOrEqual(top1, 79, "top-1 regressed vs JS reference (80/82). Misses: \(misses)")
        XCTAssertGreaterThanOrEqual(top3, n - 1, "top-3 regressed vs JS reference (82/82). Misses: \(misses)")
    }

    func testLatencyBudget() {
        // Keyboard extensions need suggestions well under 16ms/keystroke.
        let t0 = Date()
        for _ in 0..<200 { _ = Self.engine.suggest("gamarjoba", max: 5) }
        let avgMs = -t0.timeIntervalSinceNow * 1000 / 200
        XCTAssertLessThan(avgMs, 5.0, "avg suggest latency \(avgMs)ms exceeds budget")
    }

    func testNextWordPrediction() {
        let preds = Self.engine.predictNext(after: "როგორ", max: 3)
        XCTAssertFalse(preds.isEmpty, "bigram predictions should exist for common words")
    }

    // (latin input, expected georgian) — keep in sync with engine/test.js
    static let cases: [(String, String)] = [
        ("saxlshi", "სახლში"),
        ("xar", "ხარ"),
        ("gamarjoba", "გამარჯობა"),
        ("rogor", "როგორ"),
        ("ra", "რა"),
        ("aris", "არის"),
        ("kargad", "კარგად"),
        ("madloba", "მადლობა"),
        ("dzalian", "ძალიან"),
        ("tbilisshi", "თბილისში"),
        ("shen", "შენ"),
        ("chven", "ჩვენ"),
        ("ojaxi", "ოჯახი"),
        ("sikvaruli", "სიყვარული"),
        ("gilocav", "გილოცავ"),
        ("dges", "დღეს"),
        ("xval", "ხვალ"),
        ("gushin", "გუშინ"),
        ("sadili", "სადილი"),
        ("wigni", "წიგნი"),
        ("tsavedit", "წავედით"),
        ("gogo", "გოგო"),
        ("bichi", "ბიჭი"),
        ("qali", "ქალი"),
        ("kaci", "კაცი"),
        ("bavshvi", "ბავშვი"),
        ("deda", "დედა"),
        ("mama", "მამა"),
        ("dzma", "ძმა"),
        ("da", "და"),
        ("tu", "თუ"),
        ("ki", "კი"),
        ("ara", "არა"),
        ("diax", "დიახ"),
        ("gmadlobt", "გმადლობთ"),
        ("ukacravad", "უკაცრავად"),
        ("sakartvelo", "საქართველო"),
        ("kartuli", "ქართული"),
        ("ena", "ენა"),
        ("tsqali", "წყალი"),
        ("wyali", "წყალი"),
        ("puri", "პური"),
        ("ghvino", "ღვინო"),
        ("gvino", "ღვინო"),
        ("tsiteli", "წითელი"),
        ("lamazi", "ლამაზი"),
        ("didi", "დიდი"),
        ("patara", "პატარა"),
        ("axali", "ახალი"),
        ("dzveli", "ძველი"),
        ("modi", "მოდი"),
        ("tsadi", "წადი"),
        ("minda", "მინდა"),
        ("ginda", "გინდა"),
        ("vici", "ვიცი"),
        ("ar", "არ"),
        ("var", "ვარ"),
        ("iyo", "იყო"),
        ("ikneba", "იქნება"),
        ("dღes", "დღეს"),
        ("gaigebs", "გაიგებს"),
        ("gagimarjos", "გაგიმარჯოს"),
        ("nakhvamdis", "ნახვამდის"),
        ("naxvamdis", "ნახვამდის"),
        ("tamashi", "თამაში"),
        ("simghera", "სიმღერა"),
        ("cekva", "ცეკვა"),
        ("mze", "მზე"),
        ("mtvare", "მთვარე"),
        ("zgva", "ზღვა"),
        ("zghva", "ზღვა"),
        ("mta", "მთა"),
        ("gza", "გზა"),
        ("manqana", "მანქანა"),
        ("fuli", "ფული"),
        ("dro", "დრო"),
        ("weli", "წელი"),
        ("tve", "თვე"),
        ("kvira", "კვირა"),
        ("dila", "დილა"),
        ("saghamo", "საღამო"),
        ("ghame", "ღამე"),    ]
}
