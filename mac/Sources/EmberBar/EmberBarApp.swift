import EmberBarCore
import SwiftUI

@main
struct EmberBarApp: App {
    @StateObject private var store = UsageStore()
    @State private var signedIn = Demo.enabled || Auth.signedIn
    @State private var status = ""

    var body: some Scene {
        MenuBarExtra {
            if !status.isEmpty { Text(status) }
            if !store.message.isEmpty { Text(store.message) }
            if signedIn {
                Button("Refresh now") { Task { await store.refresh() } }
                Button("Sign out") {
                    Auth.signOut()
                    store.reset()
                    signedIn = false
                    status = ""
                }
            } else {
                Button("Sign in with Claude") { signIn() }
            }
            Divider()
            Button("Quit EmberBar") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            label
                .task { store.start() }
        }
    }

    private var label: some View {
        Image(nsImage: StatusImage.make(usage: store.usage, stale: store.stale, signedIn: signedIn))
            .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        guard let u = store.usage else { return "EmberBar" }
        return "5-hour limit \(Int(u.fiveHour.percent.rounded())) percent, weekly limit \(Int(u.week.percent.rounded())) percent"
    }

    private func signIn() {
        status = "Waiting for the browser…"
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
}
