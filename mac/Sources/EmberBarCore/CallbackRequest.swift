import Foundation

/// Strict parser for the one HTTP request the loopback sign-in server accepts.
///
/// Anything that is not exactly `GET /callback?...` addressed to `localhost:<port>` /
/// `127.0.0.1:<port>` is rejected. That blocks DNS-rebinding and drive-by requests from web pages
/// or other local programs. Invalid requests never end the sign-in: only a genuine
/// provider error or a valid code does.
public enum CallbackOutcome: Equatable {
    /// Not our request (wrong path/method/host, bad state, malformed). Answer with `status`, keep waiting.
    case reject(status: Int)
    /// The provider reported an error for our own `state`. Ends the sign-in.
    case providerError
    case code(String)
}

public enum CallbackRequest {
    public static let maxRequestBytes = 8192
    public static let maxCodeLength = 2048

    public static func evaluate(raw: String, expectedState: String, port: UInt16) -> CallbackOutcome {
        guard raw.utf8.count <= maxRequestBytes else { return .reject(status: 400) }

        let lines = raw.components(separatedBy: "\r\n")
        let start = (lines.first ?? "").split(separator: " ", omittingEmptySubsequences: false)
        guard start.count == 3, start[0] == "GET", start[2].hasPrefix("HTTP/1.") else { return .reject(status: 400) }

        // Host header must be our own loopback origin.
        let allowedHosts: Set<String> = ["localhost:\(port)", "127.0.0.1:\(port)"]
        let host = lines.dropFirst()
            .first { $0.lowercased().hasPrefix("host:") }
            .map { $0.dropFirst(5).trimmingCharacters(in: .whitespaces).lowercased() }
        guard let host, allowedHosts.contains(host) else { return .reject(status: 400) }

        guard let comps = URLComponents(string: "http://localhost" + start[1]), comps.path == "/callback" else {
            return .reject(status: 404)
        }
        let items = comps.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        // Constant-shape check on state first: without our state nothing else is trusted.
        guard let state = value("state"), constantTimeEqual(state, expectedState) else { return .reject(status: 400) }

        if value("error") != nil { return .providerError }
        guard let code = value("code"), !code.isEmpty, code.utf8.count <= maxCodeLength,
              code.unicodeScalars.allSatisfy({ $0.value > 0x20 && $0.value < 0x7f })
        else { return .reject(status: 400) }
        return .code(code)
    }

    static func constantTimeEqual(_ a: String, _ b: String) -> Bool {
        let x = Array(a.utf8), y = Array(b.utf8)
        guard x.count == y.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<x.count { diff |= x[i] ^ y[i] }
        return diff == 0
    }
}
