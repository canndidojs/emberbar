import EmberBarCore
import Foundation

enum UsageClientError: LocalizedError {
    case rateLimited
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .rateLimited: return L.t("err.rate")
        case .http(let code): return L.t("err.http", code)
        }
    }
}

/// Fetches /api/oauth/usage (port of Program.cs `FetchAsync`).
enum UsageClient {
    private static let url = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    static func fetch() async throws -> Usage {
        let token = try await Auth.accessToken()
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("EmberBar-mac", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await SecureSession.data(for: req)
        let status = resp.statusCode
        guard (200..<300).contains(status) else {
            throw status == 429 ? UsageClientError.rateLimited : UsageClientError.http(status)
        }
        return try UsageParser.parse(data)
    }
}

/// `EMBERBAR_DEMO=1` shows fixed fake values and skips sign-in. Used by CI to take a screenshot without an account.
enum Demo {
    static let enabled = ProcessInfo.processInfo.environment["EMBERBAR_DEMO"] == "1"
    static let usage = Usage(
        fiveHour: UsageWindow(percent: 72, resetsAt: Date().addingTimeInterval(3 * 3600)),
        week: UsageWindow(percent: 38, resetsAt: Date().addingTimeInterval(4 * 86400))
    )
}

/// Observable usage state: keeps the last good reading (shown stale on failure) and polls with backoff.
@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var usage: Usage?
    @Published private(set) var stale = false
    @Published private(set) var message = ""
    @Published private(set) var lastUpdate: Date?

    private var failures = 0
    private var busy = false
    private var loop: Task<Void, Never>?
    var baseInterval: TimeInterval = 300

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if Demo.enabled || Auth.signedIn { await self.refresh() }
                let wait = Polling.nextInterval(base: self.baseInterval, failures: self.failures)
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    func reset() {
        usage = nil
        stale = false
        message = ""
        failures = 0
    }

    func refresh() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        if Demo.enabled {
            usage = Demo.usage
            lastUpdate = Date()
            return
        }
        do {
            usage = try await UsageClient.fetch()
            lastUpdate = Date()
            stale = false
            message = ""
            failures = 0
        } catch {
            failures += 1
            stale = usage != nil
            message = error.localizedDescription
            if case AuthError.expired = error { usage = nil }
        }
    }
}
