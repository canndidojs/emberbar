import XCTest
@testable import EmberBarCore

final class UsageParserTests: XCTestCase {
    func testParsesBothWindows() throws {
        let json = """
        {"five_hour":{"utilization":42.5,"resets_at":"2026-11-13T18:00:00.123Z"},
         "seven_day":{"utilization":78,"resets_at":"2026-11-17T00:00:00Z"}}
        """
        let u = try UsageParser.parse(Data(json.utf8))
        XCTAssertEqual(u.fiveHour.percent, 42.5)
        XCTAssertEqual(u.week.percent, 78)
        XCTAssertNotNil(u.fiveHour.resetsAt)
        XCTAssertNotNil(u.week.resetsAt)
    }

    func testMissingResetIsNil() throws {
        let json = #"{"five_hour":{"utilization":1,"resets_at":null},"seven_day":{"utilization":2}}"#
        let u = try UsageParser.parse(Data(json.utf8))
        XCTAssertNil(u.fiveHour.resetsAt)
        XCTAssertNil(u.week.resetsAt)
    }

    func testMissingFieldThrows() {
        let json = #"{"five_hour":{"utilization":1}}"#
        XCTAssertThrowsError(try UsageParser.parse(Data(json.utf8))) {
            XCTAssertEqual($0 as? UsageParseError, .missingField("seven_day"))
        }
    }

    func testBadUtilizationThrows() {
        for bad in [#""x""#, "null", "true"] {
            let json = #"{"five_hour":{"utilization":\#(bad)},"seven_day":{"utilization":1}}"#
            XCTAssertThrowsError(try UsageParser.parse(Data(json.utf8)), bad) {
                XCTAssertEqual($0 as? UsageParseError, .badValue("five_hour"))
            }
        }
    }

    func testNotJSONThrows() {
        XCTAssertThrowsError(try UsageParser.parse(Data("nope".utf8))) {
            XCTAssertEqual($0 as? UsageParseError, .notJSON)
        }
    }
}

final class UsageLevelTests: XCTestCase {
    func testThresholds() {
        XCTAssertEqual(UsageLevel(percent: 69.9), .normal)
        XCTAssertEqual(UsageLevel(percent: 70), .warning)
        XCTAssertEqual(UsageLevel(percent: 89.9), .warning)
        XCTAssertEqual(UsageLevel(percent: 90), .critical)
    }
}

final class PKCETests: XCTestCase {
    // RFC 7636 appendix B test vector.
    func testChallengeMatchesRFCVector() {
        XCTAssertEqual(
            PKCE.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"),
            "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    func testBase64URLHasNoPaddingOrUnsafeChars() {
        let s = PKCE.base64URL(Data([0xfb, 0xff, 0xfe, 0x01]))
        XCTAssertEqual(s, "-__-AQ")
        XCTAssertFalse(s.contains("="))
    }

    func testRandomBytesLengthAndVariety() {
        XCTAssertEqual(PKCE.randomBytes(32).count, 32)
        XCTAssertNotEqual(PKCE.randomBytes(32), PKCE.randomBytes(32))
    }
}

final class PollingTests: XCTestCase {
    func testBackoffDoublesThenCaps() {
        XCTAssertEqual(Polling.nextInterval(base: 120, failures: 0), 120)
        XCTAssertEqual(Polling.nextInterval(base: 120, failures: 1), 240)
        XCTAssertEqual(Polling.nextInterval(base: 120, failures: 2), 480)
        XCTAssertEqual(Polling.nextInterval(base: 120, failures: 3), 600)
        XCTAssertEqual(Polling.nextInterval(base: 120, failures: 50), 600)
    }

    func testCapNeverBelowBase() {
        XCTAssertEqual(Polling.nextInterval(base: 1800, failures: 3), 1800)
    }
}
