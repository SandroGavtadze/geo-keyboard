import XCTest
@testable import GeorgianIME

final class TokenizerTests: XCTestCase {
    func testExtract() throws {
        let t = Tokenizer()
        let ctx = t.extract(fromBeforeCaret: "გამარჯობა როგორ ხარ")
        XCTAssertEqual(ctx.currentToken, "ხარ")
        XCTAssertEqual(ctx.prevToken, "როგორ")
    }
}
