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
        Group {
            if let u = store.usage {
                // Colored text is not supported in the menu bar label; stale is shown with a trailing "?".
                Text("5h \(Int(u.fiveHour.percent.rounded()))% · W \(Int(u.week.percent.rounded()))%\(store.stale ? " ?" : "")")
            } else {
                Text(signedIn ? "EmberBar …" : "EmberBar")
            }
        }
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
