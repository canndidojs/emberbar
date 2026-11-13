import Foundation

public enum UsageParseError: Error, Equatable {
    case notJSON
    case missingField(String)
    case badValue(String)
}

/// Parses the /api/oauth/usage response (port of Program.cs `FetchAsync` / `Window`).
public enum UsageParser {
    public static func parse(_ data: Data) throws -> Usage {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageParseError.notJSON
        }
        return Usage(fiveHour: try window(root, "five_hour"), week: try window(root, "seven_day"))
    }

    private static func window(_ root: [String: Any], _ field: String) throws -> UsageWindow {
        guard let w = root[field] as? [String: Any] else { throw UsageParseError.missingField(field) }
        // NSNumber also matches Bool; reject it so `true` is not read as 1%.
        guard let u = w["utilization"] as? NSNumber, CFGetTypeID(u) != CFBooleanGetTypeID(),
              u.doubleValue.isFinite, (0...1000).contains(u.doubleValue)
        else {
            // Out-of-range values would otherwise crash `Int(_)` conversions when drawn.
            throw UsageParseError.badValue(field)
        }
        return UsageWindow(percent: u.doubleValue, resetsAt: (w["resets_at"] as? String).flatMap(parseDate))
    }

    private static func parseDate(_ s: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: s) { return d }
        return ISO8601DateFormatter().date(from: s)
    }
}
