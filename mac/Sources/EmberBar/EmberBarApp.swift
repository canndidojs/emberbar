import AppKit
import EmberBarCore
import SwiftUI

@main
struct EmberBarApp: App {
    @StateObject private var store = UsageStore()
    @StateObject private var settings = Settings()
    @StateObject private var updater = Updater()
    @State private var signedIn = Demo.enabled || Auth.signedIn
    @State private var status = ""

    // Only fixed, hardcoded URLs are opened from here. The update link is validated by ReleaseParser.
    private static let usagePage = URL(string: "https://claude.ai/settings/usage")!

    var body: some Scene {
        MenuBarExtra {
            menu
        } label: {
            label
                .task {
                    store.baseInterval = settings.interval
                    store.start()
                    await checkUpdatesForever()
                }
        }
    }

    // MARK: - Menu

    @ViewBuilder private var menu: some View {
        if let u = store.usage {
            Text(L.t("line.five", Int(u.fiveHour.percent.rounded())))
            if let line = resetLine(u.fiveHour.resetsAt) { Text(line) }
            Text(L.t("line.week", Int(u.week.percent.rounded())))
            if let line = resetLine(u.week.resetsAt) { Text(line) }
            if store.stale { Text(L.t("line.stale")) }
            else if let at = store.lastUpdate {
                Text(L.t("line.updated", at.formatted(date: .omitted, time: .shortened)))
            }
            Divider()
        } else if signedIn {
            Text(L.t("state.loading"))
            Divider()
        }
        if !status.isEmpty { Text(status) }
        if !store.message.isEmpty { Text(store.message) }

        if let release = updater.available {
            Button(L.t("menu.update", release.version)) { NSWorkspace.shared.open(release.url) }
            Divider()
        }

        if signedIn {
            Button(L.t("menu.refresh")) { Task { await store.refresh() } }
            Picker(L.t("menu.interval"), selection: intervalBinding) {
                ForEach(Polling.intervals, id: \.self) { Text(TimeText.remaining($0)).tag($0) }
            }
            Button(L.t("menu.usage")) { NSWorkspace.shared.open(Self.usagePage) }
        }
        Picker(L.t("menu.language"), selection: $settings.language) {
            ForEach(Lang.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }
        Toggle(L.t("menu.startup"), isOn: Binding(
            get: { settings.launchAtLogin },
            set: { settings.setLaunchAtLogin($0) }))
        Button(L.t("menu.checkupdate")) { Task { await updater.check() } }
        Divider()

        if signedIn {
            Button(L.t("menu.signout")) {
                Auth.signOut()
                store.reset()
                signedIn = false
                status = ""
            }
        } else {
            Button(L.t("menu.signin")) { signIn() }
        }
        Button(L.t("menu.quit")) { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var intervalBinding: Binding<TimeInterval> {
        Binding(get: { settings.interval }, set: { settings.interval = $0; store.baseInterval = $0 })
    }

    private func resetLine(_ date: Date?) -> String? {
        guard let date else { return nil }
        let left = date.timeIntervalSinceNow
        let when = TimeText.resetLabel(date)
        return left > 0 ? L.t("line.resets", when, TimeText.remaining(left)) : L.t("line.resets.now", when)
    }

    // MARK: - Label

    private var label: some View {
        _ = settings.language // redraw the image when the language changes
        return Image(nsImage: StatusImage.make(usage: store.usage, stale: store.stale, signedIn: signedIn))
            .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        guard let u = store.usage else { return "EmberBar" }
        return "\(L.t("line.five", Int(u.fiveHour.percent.rounded()))), \(L.t("line.week", Int(u.week.percent.rounded())))"
    }

    // MARK: - Actions

    private func signIn() {
        status = L.t("state.waiting")
        Task {
            do {
                try await Auth.login()
                signedIn = true
                status = ""
                await store.refresh()
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func checkUpdatesForever() async {
        guard !Demo.enabled else { return }
        try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
        while !Task.isCancelled {
            await updater.check()
            try? await Task.sleep(nanoseconds: 12 * 3600 * 1_000_000_000)
        }
    }
}
