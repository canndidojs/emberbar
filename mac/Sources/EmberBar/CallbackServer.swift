import Foundation
import Network

/// One-shot HTTP server on a random loopback port that captures the OAuth redirect.
final class CallbackServer: @unchecked Sendable {
    private let expectedState: String
    private let queue = DispatchQueue(label: "emberbar.callback")
    private var listener: NWListener?
    private var codeContinuation: CheckedContinuation<String, Error>?
    private var pending: Result<String, Error>?

    init(expectedState: String) { self.expectedState = expectedState }

    /// Starts listening on the loopback interface and returns the chosen port.
    func start() async throws -> UInt16 {
        let params = NWParameters.tcp
        params.requiredInterfaceType = .loopback
        let listener = try NWListener(using: params, on: .any)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] conn in self?.handle(conn) }

        return try await withCheckedThrowingContinuation { cont in
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
    }

    func stop() { listener?.cancel() }

    func waitForCode() async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            queue.async {
                if let result = self.pending { cont.resume(with: result) }
                else { self.codeContinuation = cont }
            }
        }
    }

    private func finish(_ result: Result<String, Error>) {
        if let cont = codeContinuation {
            codeContinuation = nil
            cont.resume(with: result)
        } else {
            pending = result
        }
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let self, let data, let text = String(data: data, encoding: .utf8) else { conn.cancel(); return }
            let parts = text.components(separatedBy: "\r\n").first?.split(separator: " ") ?? []
            guard parts.count >= 2, parts[1].hasPrefix("/callback") else {
                self.reply(conn, "Not found.", status: 404)
                return
            }

            let items = URLComponents(string: "http://localhost" + parts[1])?.queryItems ?? []
            func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

            if let error = value("error") {
                self.reply(conn, "Sign-in failed: \(error)", status: 400)
                self.finish(.failure(AuthError.badResponse))
            } else if value("state") != self.expectedState || (value("code") ?? "").isEmpty {
                self.reply(conn, "Invalid response.", status: 400)
                self.finish(.failure(AuthError.badResponse))
            } else {
                self.reply(conn, "Signed in. You can close this tab.", status: 200)
                self.finish(.success(value("code")!))
            }
        }
    }

    private func reply(_ conn: NWConnection, _ message: String, status: Int) {
        let escaped = message
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let html = "<!doctype html><meta charset=utf-8><title>EmberBar</title>"
            + "<body style=\"margin:0;height:100vh;display:grid;place-items:center;background:#000;color:#fff;font:16px -apple-system,sans-serif\">"
            + "<p>\(escaped)</p>"
        let body = Data(html.utf8)
        let head = "HTTP/1.1 \(status) OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        conn.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in conn.cancel() })
    }
}
