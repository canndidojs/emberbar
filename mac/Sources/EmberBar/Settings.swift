import EmberBarCore
import Foundation
import ServiceManagement

/// Local preferences only (UserDefaults inside the app sandbox container). Nothing here leaves the device.
@MainActor
final class Settings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var language: Lang {
        didSet { defaults.set(language.rawValue, forKey: "language"); L.current = language }
    }

    @Published var interval: TimeInterval {
        didSet { defaults.set(interval, forKey: "interval") }
    }

    @Published private(set) var launchAtLogin: Bool

    init() {
        let stored = defaults.string(forKey: "language").flatMap(Lang.init(rawValue:))
        language = stored ?? .detect()
        L.current = language

        let saved = defaults.double(forKey: "interval")
        interval = Polling.intervals.contains(saved) ? saved : 300

        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            // Not running from a signed .app bundle (e.g. `swift run`): nothing to register.
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
