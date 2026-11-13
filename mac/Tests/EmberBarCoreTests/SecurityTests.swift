import XCTest
@testable import EmberBarCore

final class CallbackRequestTests: XCTestCase {
    let state = "s3cr3t-state"
    let port: UInt16 = 51234

    func request(_ target: String, method: String = "GET", host: String? = nil, version: String = "HTTP/1.1") -> String {
        let h = host ?? "localhost:\(port)"
        return "\(method) \(target) \(version)\r\nHost: \(h)\r\nUser-Agent: test\r\n\r\n"
    }

    func eval(_ raw: String) -> CallbackOutcome {
        CallbackRequest.evaluate(raw: raw, expectedState: state, port: port)
    }

    func testValidCode() {
        XCTAssertEqual(eval(request("/callback?code=abc123&state=\(state)")), .code("abc123"))
    }

    func testAcceptsLoopbackIPHost() {
        XCTAssertEqual(eval(request("/callback?code=abc&state=\(state)", host: "127.0.0.1:\(port)")), .code("abc"))
    }

    func testRejectsForeignHostHeader() {
        // DNS rebinding: a web page resolving evil.example to 127.0.0.1.
        XCTAssertEqual(eval(request("/callback?code=abc&state=\(state)", host: "evil.example:\(port)")), .reject(status: 400))
        XCTAssertEqual(eval(request("/callback?code=abc&state=\(state)", host: "localhost:1")), .reject(status: 400))
    }

    func testRejectsMissingHostHeader() {
        XCTAssertEqual(eval("GET /callback?code=abc&state=\(state) HTTP/1.1\r\n\r\n"), .reject(status: 400))
    }

    func testRejectsWrongOrMissingState() {
        XCTAssertEqual(eval(request("/callback?code=abc&state=nope")), .reject(status: 400))
        XCTAssertEqual(eval(request("/callback?code=abc")), .reject(status: 400))
        XCTAssertEqual(eval(request("/callback?code=abc&state=\(state)x")), .reject(status: 400))
    }

    func testWrongStateCannotAbortSignIn() {
        // A hostile page must not be able to end the sign-in with a fake provider error.
        XCTAssertEqual(eval(request("/callback?error=access_denied&state=guess")), .reject(status: 400))
        XCTAssertEqual(eval(request("/callback?error=access_denied")), .reject(status: 400))
    }

    func testProviderErrorWithOurState() {
        XCTAssertEqual(eval(request("/callback?error=access_denied&state=\(state)")), .providerError)
    }

    func testRejectsOtherPathsAndMethods() {
        XCTAssertEqual(eval(request("/favicon.ico")), .reject(status: 404))
        XCTAssertEqual(eval(request("/callback/../x?code=a&state=\(state)")), .reject(status: 404))
        XCTAssertEqual(eval(request("/callback?code=a&state=\(state)", method: "POST")), .reject(status: 400))
        XCTAssertEqual(eval(request("/callback?code=a&state=\(state)", version: "SPDY/3")), .reject(status: 400))
    }

    func testRejectsEmptyOrHostileCode() {
        XCTAssertEqual(eval(request("/callback?code=&state=\(state)")), .reject(status: 400))
        XCTAssertEqual(eval(request("/callback?code=a%20b&state=\(state)")), .reject(status: 400))
        XCTAssertEqual(eval(request("/callback?code=a%00b&state=\(state)")), .reject(status: 400))
        XCTAssertEqual(eval(request("/callback?code=%3Cscript%3E%C3%A9&state=\(state)")), .reject(status: 400))
    }

    func testRejectsOversizedInput() {
        let long = String(repeating: "a", count: CallbackRequest.maxCodeLength + 1)
        XCTAssertEqual(eval(request("/callback?code=\(long)&state=\(state)")), .reject(status: 400))
        let huge = request("/callback?code=a&state=\(state)") + String(repeating: "x", count: CallbackRequest.maxRequestBytes)
        XCTAssertEqual(eval(huge), .reject(status: 400))
    }

    func testConstantTimeEqual() {
        XCTAssertTrue(CallbackRequest.constantTimeEqual("abc", "abc"))
        XCTAssertFalse(CallbackRequest.constantTimeEqual("abc", "abd"))
        XCTAssertFalse(CallbackRequest.constantTimeEqual("abc", "abcd"))
    }
}

final class UsageRangeTests: XCTestCase {
    func parse(_ value: String) throws -> Usage {
        try UsageParser.parse(Data(#"{"five_hour":{"utilization":\#(value)},"seven_day":{"utilization":1}}"#.utf8))
    }

    func testAcceptsBoundaryValues() throws {
        XCTAssertEqual(try parse("0").fiveHour.percent, 0)
        XCTAssertEqual(try parse("100").fiveHour.percent, 100)
        XCTAssertEqual(try parse("100.5").fiveHour.percent, 100.5)
    }

    func testRejectsOutOfRange() {
        // Int(Double) traps on huge values; these must be rejected at the parser.
        for bad in ["-1", "1e300", "1001", "1e999"] {
            XCTAssertThrowsError(try parse(bad), bad)
        }
    }
}
