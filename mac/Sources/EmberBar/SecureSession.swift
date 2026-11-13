import Foundation

/// URLSession for requests that carry credentials.
///
/// - Ephemeral: nothing (cookies, cache, credentials) is written to disk.
/// - No redirects: a redirect could forward the Authorization header or tokens to another host.
/// - HTTPS only and only the expected host (App Transport Security already rejects plain HTTP;
///   the host check guards against a bug passing the wrong URL with a token).
enum SecureSession {
    private final class NoRedirect: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest,
                        completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(nil)
        }
    }

    private static let delegate = NoRedirect()
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }()

    /// Hosts that may receive credentials. Anything else is refused.
    static let credentialHosts: Set<String> = ["api.anthropic.com", "platform.claude.com"]

    static func data(for request: URLRequest, allowedHosts: Set<String> = credentialHosts) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url, url.scheme == "https", let host = url.host, allowedHosts.contains(host) else {
            throw URLError(.unsupportedURL)
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        // Responses are tiny JSON documents; refuse anything unreasonable.
        guard data.count <= 1_000_000 else { throw URLError(.dataLengthExceedsMaximum) }
        return (data, http)
    }
}
