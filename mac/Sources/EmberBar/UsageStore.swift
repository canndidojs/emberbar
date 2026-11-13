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

    /// `EMBERBAR_DEMO_WINDOW=history` opens the history window at launch (for the CI screenshot).
    static let opensHistory = enabled && ProcessInfo.processInfo.environment["EMBERBAR_DEMO_WINDOW"] == "history"

    /// Six months of made-up daily peaks, in memory only. Demo mode never reads or writes the real history file.
    static let history: UsageHistory = {
        var h = UsageHistory()
        let now = Date()
        for offset in stride(from: 170, through: 0, by: -3) {
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: now) else { continue }
            let five = Double(35 + (offset * 7) % 55), week = Double(15 + (offset * 13) % 70)
            h.record(Usage(fiveHour: UsageWindow(percent: five, resetsAt: nil),
                           week: UsageWindow(percent: week, resetsAt: nil)), now: day)
        }
        return h
    }()
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
    /// Called after each successful real reading (never for demo values).
    var onSuccess: ((Usage) -> Void)?

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
            let fresh = try await UsageClient.fetch()
            usage = fresh
            onSuccess?(fresh)
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
