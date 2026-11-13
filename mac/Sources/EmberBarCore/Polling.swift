import Foundation

public enum Polling {
    public static let intervals: [TimeInterval] = [120, 300, 600, 900, 1800]

    /// Backoff after failures, same as Program.cs: base * 2^min(failures, 5), capped at max(600s, base).
    public static func nextInterval(base: TimeInterval, failures: Int) -> TimeInterval {
        let cap = max(600, base)
        return min(base * Double(1 << min(max(failures, 0), 5)), cap)
    }
}
