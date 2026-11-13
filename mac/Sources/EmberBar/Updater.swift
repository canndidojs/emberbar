import EmberBarCore
import Foundation

/// Looks for a newer macOS release on GitHub. It only reports a link to open in the browser:
/// nothing is downloaded or executed. The request carries no account data and no identifiers.
@MainActor
final class Updater: ObservableObject {
    @Published private(set) var available: ReleaseInfo?
    @Published private(set) var upToDate = false

    private static let listURL = URL(string: "https://api.github.com/repos/canndidojs/emberbar/releases?per_page=20")!

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    func check() async {
        var req = URLRequest(url: Self.listURL, timeoutInterval: 15)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("EmberBar", forHTTPHeaderField: "User-Agent")
        guard let (data, resp) = try? await SecureSession.data(for: req, allowedHosts: ["api.github.com"]),
              resp.statusCode == 200
        else { return }

        if let release = ReleaseParser.latest(from: data), ReleaseParser.isNewer(release.version, than: Self.currentVersion) {
            available = release
            upToDate = false
        } else {
            available = nil
            upToDate = true
        }
    }
}
