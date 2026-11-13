import XCTest
@testable import EmberBarCore

final class StringsTests: XCTestCase {
    func testEveryLanguageHasEveryKey() {
        let english = Set(L.table[.en]!.keys)
        for lang in Lang.allCases {
            let keys = Set(L.table[lang]!.keys)
            XCTAssertEqual(english.subtracting(keys), [], "\(lang) is missing keys")
            XCTAssertEqual(keys.subtracting(english), [], "\(lang) has extra keys")
        }
    }

    func testPlaceholdersMatchAcrossLanguages() {
        func count(_ s: String, _ token: String) -> Int { s.components(separatedBy: token).count - 1 }
        for (key, en) in L.table[.en]! {
            for lang in Lang.allCases {
                let other = L.table[lang]![key]!
                XCTAssertEqual(count(other, "%@"), count(en, "%@"), "\(key) [\(lang)] %@")
                XCTAssertEqual(count(other, "%d"), count(en, "%d"), "\(key) [\(lang)] %d")
            }
        }
    }

    func testFormatting() {
        XCTAssertEqual(L.t("line.five", in: .pt, 72), "Limite de 5 horas: 72%")
        XCTAssertEqual(L.t("line.resets", in: .en, "21:40", "2h 15min"), "Resets 21:40 (in 2h 15min)")
    }

    func testLanguageDetection() {
        XCTAssertEqual(Lang.detect(preferred: ["pt-BR", "en-US"]), .pt)
        XCTAssertEqual(Lang.detect(preferred: ["es_MX"]), .es)
        XCTAssertEqual(Lang.detect(preferred: ["fr-FR", "es-ES"]), .es)
        XCTAssertEqual(Lang.detect(preferred: ["fr-FR"]), .en)
        XCTAssertEqual(Lang.detect(preferred: []), .en)
    }
}

final class TimeTextTests: XCTestCase {
    func testRemaining() {
        XCTAssertEqual(TimeText.remaining(-5, lang: .en), "0min")
        XCTAssertEqual(TimeText.remaining(45 * 60, lang: .en), "45min")
        XCTAssertEqual(TimeText.remaining(2 * 3600 + 15 * 60, lang: .en), "2h 15min")
        XCTAssertEqual(TimeText.remaining(3 * 3600, lang: .en), "3h")
        XCTAssertEqual(TimeText.remaining(3 * 86400 + 4 * 3600, lang: .en), "3d 4h")
        XCTAssertEqual(TimeText.remaining(2 * 86400, lang: .en), "2d")
    }
}

final class ReleaseParserTests: XCTestCase {
    func release(_ tag: String, url: String? = nil, draft: Bool = false, pre: Bool = false) -> String {
        let u = url ?? "https://github.com/canndidojs/emberbar/releases/tag/\(tag)"
        return #"{"tag_name":"\#(tag)","html_url":"\#(u)","draft":\#(draft),"prerelease":\#(pre)}"#
    }

    func parse(_ items: [String]) -> ReleaseInfo? {
        ReleaseParser.latest(from: Data("[\(items.joined(separator: ","))]".utf8))
    }

    func testPicksNewestMacRelease() {
        let r = parse([release("v1.2.0"), release("mac-v0.1.0"), release("mac-v0.2.0"), release("mac-v0.1.5")])
        XCTAssertEqual(r?.version, "0.2.0")
    }

    func testIgnoresDraftsPrereleasesAndWindowsTags() {
        XCTAssertNil(parse([release("mac-v9.0.0", draft: true), release("mac-v8.0.0", pre: true), release("v1.2.0")]))
    }

    func testRejectsForeignOrNonHTTPSLinks() {
        XCTAssertNil(parse([release("mac-v1.0.0", url: "https://evil.example/canndidojs/emberbar/releases/x")]))
        XCTAssertNil(parse([release("mac-v1.0.0", url: "http://github.com/canndidojs/emberbar/releases/x")]))
        // Path traversal out of our releases page.
        XCTAssertNil(parse([release("mac-v1.0.0", url: "https://github.com/canndidojs/emberbar/releases/../../evil")]))
    }

    func testRejectsMalformedVersions() {
        XCTAssertNil(parse([release("mac-v1.0"), release("mac-v1.0.0-beta"), release("mac-vx.y.z"), release("mac-v1..0")]))
    }

    func testGarbageInput() {
        XCTAssertNil(ReleaseParser.latest(from: Data("not json".utf8)))
        XCTAssertNil(ReleaseParser.latest(from: Data("{}".utf8)))
    }

    func testVersionComparison() {
        XCTAssertTrue(ReleaseParser.isNewer("0.2.0", than: "0.1.9"))
        XCTAssertTrue(ReleaseParser.isNewer("1.0.0", than: "0.9.9"))
        XCTAssertTrue(ReleaseParser.isNewer("0.10.0", than: "0.9.0"))
        XCTAssertFalse(ReleaseParser.isNewer("0.1.0", than: "0.1.0"))
        XCTAssertFalse(ReleaseParser.isNewer("0.1.0", than: "0.2.0"))
        XCTAssertFalse(ReleaseParser.isNewer("garbage", than: "0.1.0"))
    }
}
