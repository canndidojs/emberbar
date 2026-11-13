import EmberBarCore
import Foundation
import UserNotifications

/// Owns the usage history file and raises usage alerts.
///
/// The history lives only in the app's sandbox container (Application Support/EmberBar/history.json),
/// readable by the current user only. It holds daily percentages, never tokens or account data.
@MainActor
final class Recorder: ObservableObject {
    @Published private(set) var history: UsageHistory
    private var alerts = AlertTracker()

    private static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("EmberBar", isDirectory: true)
    }()
    private static let file = directory.appendingPathComponent("history.json")

    init() {
        if Demo.enabled { history = Demo.history; return }
        if let data = try? Data(contentsOf: Self.file) { history = UsageHistory(decoding: data) }
        else { history = UsageHistory() }
    }

    /// Called after every successful reading. Never called in demo mode, so fake values are never stored.
    func handle(_ usage: Usage, notify: Bool) {
        history.record(usage)
        save()

        let windows: [(Double, Date?, String)] = [
            (usage.fiveHour.percent, usage.fiveHour.resetsAt, "alert.five"),
            (usage.week.percent, usage.week.resetsAt, "alert.week"),
        ]
        for (i, (percent, resets, nameKey)) in windows.enumerated() {
            guard let level = alerts.update(window: i, percent: percent), notify else { continue }
            let name = L.t(nameKey)
            var body = level >= 100 ? L.t("alert.full", name) : L.t("alert.level", name, level)
            if let resets, resets.timeIntervalSinceNow > 0 {
                body += " " + L.t("alert.in", TimeText.remaining(resets.timeIntervalSinceNow))
            }
            Task { await Notifier.send(title: "EmberBar", body: body) }
        }
    }

    func clear() {
        history.clear()
        if !Demo.enabled { try? FileManager.default.removeItem(at: Self.file) }
    }

    private func save() {
        guard !Demo.enabled else { return }
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: Self.directory, withIntermediateDirectories: true,
                                   attributes: [.posixPermissions: 0o700])
            try history.encoded().write(to: Self.file, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: Self.file.path)
        } catch {
            // History is best effort: failing to save must never affect the menu bar.
        }
    }
}

enum Notifier {
    /// UserNotifications needs a real app bundle (not `swift run` or tests).
    private static var available: Bool { Bundle.main.bundleURL.pathExtension == "app" && !Demo.enabled }

    static func send(title: String, body: String) async {
        guard available else { return }
        let center = UNUserNotificationCenter.current()
        var settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert])
            settings = await center.notificationSettings()
        }
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
