import EmberBarCore
import Foundation
import Network

/// One-shot HTTP server on a random loopback port that captures the OAuth redirect.
///
/// Hardening: loopback interface only, strict request validation (`CallbackRequest`),
/// invalid requests never abort the sign-in, per-connection and overall timeouts,
/// a small connection cap, and fixed response bodies (no request data is reflected).
final class CallbackServer: @unchecked Sendable {
    private let expectedState: String
    private let queue = DispatchQueue(label: "emberbar.callback")
    private var listener: NWListener?
    private var port: UInt16 = 0
    private var codeContinuation: CheckedContinuation<String, Error>?
    private var pending: Result<String, Error>?
    private var connections = 0

    private static let maxConnections = 8
    private static let connectionTimeout: TimeInterval = 10
    private static let overallTimeout: TimeInterval = 300

    init(expectedState: String) { self.expectedState = expectedState }

    /// Starts listening on the loopback interface and returns the chosen port.
    func start() async throws -> UInt16 {
        let params = NWParameters.tcp
        params.requiredInterfaceType = .loopback
        let listener = try NWListener(using: params, on: .any)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] conn in self?.handle(conn) }

        let port: UInt16 = try await withCheckedThrowingContinuation { cont in
            var resumed = false
            listener.stateUpdateHandler = { state in
                guard !resumed else { return }
                switch state {
                case .ready:
                    resumed = true
                    cont.resume(returning: listener.port?.rawValue ?? 0)
                case .failed(let error):
                    resumed = true
                    cont.resume(throwing: error)
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }
        self.port = port
        queue.asyncAfter(deadline: .now() + Self.overallTimeout) { [weak self] in
            self?.finish(.failure(AuthError.timedOut))
        }
        return port
    }

    func stop() { listener?.cancel() }

    func waitForCode() async throws -> String {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { cont in
                queue.async {
                    if let result = self.pending { cont.resume(with: result) }
                    else { self.codeContinuation = cont }
                }
            }
        } onCancel: {
            queue.async { self.finish(.failure(CancellationError())) }
        }
    }

    private func finish(_ result: Result<String, Error>) {
        if let cont = codeContinuation {
            codeContinuation = nil
            cont.resume(with: result)
        } else if pending == nil {
            pending = result
        }
    }

    private func handle(_ conn: NWConnection) {
        guard connections < Self.maxConnections else { conn.cancel(); return }
        connections += 1
        conn.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state { self?.connections -= 1 }
        }
        conn.start(queue: queue)
        queue.asyncAfter(deadline: .now() + Self.connectionTimeout) { conn.cancel() }

        conn.receive(minimumIncompleteLength: 1, maximumLength: CallbackRequest.maxRequestBytes) { [weak self] data, _, _, _ in
            guard let self, let data, let text = String(data: data, encoding: .utf8) else { conn.cancel(); return }

            switch CallbackRequest.evaluate(raw: text, expectedState: self.expectedState, port: self.port) {
            case .reject(let status):
                self.reply(conn, L.t(status == 404 ? "web.notfound" : "web.invalid"), status: status)
            case .providerError:
                self.reply(conn, L.t("web.failed"), status: 400)
                self.finish(.failure(AuthError.badResponse))
            case .code(let code):
                self.reply(conn, L.t("web.ok"), status: 200)
                self.finish(.success(code))
            }
        }
    }

    private func reply(_ conn: NWConnection, _ message: String, status: Int) {
        // `message` is always one of our own constants, never request data.
        let html = "<!doctype html><meta charset=utf-8><title>EmberBar</title>"
            + "<body style=\"margin:0;height:100vh;display:grid;place-items:center;background:#000;color:#fff;font:16px -apple-system,sans-serif\">"
            + "<p>\(message)</p>"
        let body = Data(html.utf8)
        let head = "HTTP/1.1 \(status) \(status == 200 ? "OK" : "Error")\r\n"
            + "Content-Type: text/html; charset=utf-8\r\n"
            + "Content-Length: \(body.count)\r\n"
            + "Cache-Control: no-store\r\n"
            + "Referrer-Policy: no-referrer\r\n"
            + "X-Content-Type-Options: nosniff\r\n"
            + "Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'\r\n"
            + "Connection: close\r\n\r\n"
        conn.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in conn.cancel() })
    }
}
