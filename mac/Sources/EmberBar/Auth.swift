import AppKit
import EmberBarCore
import Foundation

struct Tokens: Codable {
    var access: String
    var refresh: String
    var expires: Date
}

enum AuthError: LocalizedError {
    case notSignedIn
    case expired
    case badResponse
    case server(Int)
    case noRefresh
    case timedOut
    case storage

    var errorDescription: String? {
        switch self {
        case .timedOut: return "Sign-in timed out. Try again."
        case .storage: return "Could not save the session in the Keychain."
        case .notSignedIn: return "Not signed in."
        case .expired: return "Session expired. Sign in again."
        case .badResponse: return "Invalid response from the sign-in page."
        case .server(let code): return "Server error (\(code))."
        case .noRefresh: return "The server did not return a refresh token."
        }
    }
}

/// OAuth PKCE sign-in against Anthropic, ported from Auth.cs.
enum Auth {
    private static let clientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    private static let authorizeURL = "https://claude.com/cai/oauth/authorize"
    private static let tokenURL = URL(string: "https://platform.claude.com/v1/oauth/token")!
    private static let scope = "user:profile"
    private static let account = "oauth-tokens"

    static var signedIn: Bool { load() != nil }

    static func signOut() { Keychain.delete(account: account) }

    /// Returns a valid access token, refreshing it when it expires within 2 minutes.
    static func accessToken() async throws -> String {
        guard var t = load() else { throw AuthError.notSignedIn }
        if t.expires.addingTimeInterval(-120) > Date() { return t.access }

        do {
            t = try await request([
                "grant_type": "refresh_token",
                "refresh_token": t.refresh,
                "client_id": clientId,
                "scope": scope,
            ], previousRefresh: t.refresh)
        } catch AuthError.server(let code) where [400, 401, 403].contains(code) {
            signOut()
            throw AuthError.expired
        }
        try save(t)
        return t.access
    }

    /// Opens the browser, waits for the loopback callback, exchanges the code for tokens.
    static func login() async throws {
        let verifier = PKCE.base64URL(PKCE.randomBytes(32))
        let challenge = PKCE.challenge(for: verifier)
        let state = PKCE.base64URL(PKCE.randomBytes(32))

        let server = CallbackServer(expectedState: state)
        let port = try await server.start()
        defer { server.stop() }

        let redirect = "http://localhost:\(port)/callback"
        var comps = URLComponents(string: authorizeURL)!
        comps.queryItems = [
            .init(name: "code", value: "true"),
            .init(name: "client_id", value: clientId),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: redirect),
            .init(name: "scope", value: scope),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
        ]
        let url = comps.url!
        await MainActor.run { _ = NSWorkspace.shared.open(url) }

        let code = try await server.waitForCode()
        let tokens = try await request([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirect,
            "client_id": clientId,
            "code_verifier": verifier,
            "state": state,
        ], previousRefresh: nil)
        try save(tokens)
    }

    // MARK: - Token endpoint

    private static func request(_ body: [String: String], previousRefresh: String?) async throws -> Tokens {
        var req = URLRequest(url: tokenURL, timeoutInterval: 30)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await SecureSession.data(for: req)
        guard (200..<300).contains(resp.statusCode) else { throw AuthError.server(resp.statusCode) }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String,
              let expiresIn = (json["expires_in"] as? NSNumber)?.doubleValue
        else { throw AuthError.badResponse }

        let fresh = json["refresh_token"] as? String
        let refresh: String
        if let fresh, !fresh.isEmpty { refresh = fresh }
        else if let previousRefresh { refresh = previousRefresh }
        else { throw AuthError.noRefresh }
        return Tokens(access: access, refresh: refresh, expires: Date().addingTimeInterval(expiresIn))
    }

    // MARK: - Storage

    private static func save(_ t: Tokens) throws {
        guard let data = try? JSONEncoder().encode(t), Keychain.save(data, account: account) else {
            throw AuthError.storage
        }
    }

    private static func load() -> Tokens? {
        guard let data = Keychain.load(account: account) else { return nil }
        return try? JSONDecoder().decode(Tokens.self, from: data)
    }
}
