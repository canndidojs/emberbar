import Foundation

/// One day of usage: the highest 5-hour and weekly percentages seen that day.
public struct DayUsage: Codable, Equatable {
    public let day: String   // yyyy-MM-dd
    public let peak5: Double
    public let peakWeek: Double

    public init(day: String, peak5: Double, peakWeek: Double) {
        self.day = day
        self.peak5 = peak5
        self.peakWeek = peakWeek
    }
}

public struct MonthUsage: Equatable {
    public let month: Date        // first day of the month
    public let days: Int
    public let avg5: Double?
    public let maxWeek: Double?
}

/// Daily usage peaks (port of History.cs). The API offers no past data, so this starts when recording starts.
/// Pure value type: no file access here, so it can be tested and its parsing hardened in one place.
public struct UsageHistory: Equatable {
    public static let keepDays = 200
    public static let maxEntries = 400
    public static let maxFileBytes = 1_000_000

    public private(set) var days: [DayUsage]

    public init(days: [DayUsage] = []) { self.days = days }

    /// Tolerant decoder: a corrupted or hostile file yields a clean (possibly empty) history, never a crash.
    public init(decoding data: Data) {
        guard data.count <= Self.maxFileBytes,
              let raw = try? JSONDecoder().decode([DayUsage].self, from: data)
        else { self.init(); return }

        var byDay: [String: DayUsage] = [:]
        for d in raw where Self.isValidDay(d.day) && Self.isValidPercent(d.peak5) && Self.isValidPercent(d.peakWeek) {
            if let old = byDay[d.day] {
                byDay[d.day] = DayUsage(day: d.day, peak5: max(old.peak5, d.peak5), peakWeek: max(old.peakWeek, d.peakWeek))
            } else {
                byDay[d.day] = d
            }
        }
        self.init(days: Array(byDay.values.sorted { $0.day < $1.day }.suffix(Self.maxEntries)))
    }

    public func encoded() -> Data {
        (try? JSONEncoder().encode(days)) ?? Data("[]".utf8)
    }

    public mutating func record(_ usage: Usage, now: Date = Date(), calendar: Calendar = .current) {
        let today = Self.dayKey(now, calendar: calendar)
        let p5 = usage.fiveHour.percent, pw = usage.week.percent
        if let i = days.firstIndex(where: { $0.day == today }) {
            days[i] = DayUsage(day: today, peak5: max(days[i].peak5, p5), peakWeek: max(days[i].peakWeek, pw))
        } else {
            days.append(DayUsage(day: today, peak5: p5, peakWeek: pw))
        }
        let cutoff = Self.dayKey(calendar.date(byAdding: .day, value: -Self.keepDays, to: now) ?? now, calendar: calendar)
        days.removeAll { $0.day < cutoff }
        days.sort { $0.day < $1.day }
    }

    public mutating func clear() { days.removeAll() }

    /// The last `months` months, oldest first, ending with the current one.
    public func monthly(_ months: Int, now: Date = Date(), calendar: Calendar = .current) -> [MonthUsage] {
        let parts = calendar.dateComponents([.year, .month], from: now)
        guard let first = calendar.date(from: parts) else { return [] }
        return (0..<months).reversed().compactMap { k in
            guard let m = calendar.date(byAdding: .month, value: -k, to: first) else { return nil }
            let c = calendar.dateComponents([.year, .month], from: m)
            let prefix = String(format: "%04d-%02d-", c.year ?? 0, c.month ?? 0)
            let inMonth = days.filter { $0.day.hasPrefix(prefix) }
            if inMonth.isEmpty { return MonthUsage(month: m, days: 0, avg5: nil, maxWeek: nil) }
            return MonthUsage(
                month: m,
                days: inMonth.count,
                avg5: inMonth.map(\.peak5).reduce(0, +) / Double(inMonth.count),
                maxWeek: inMonth.map(\.peakWeek).max())
        }
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    static func isValidDay(_ s: String) -> Bool {
        let p = s.split(separator: "-", omittingEmptySubsequences: false)
        guard p.count == 3, p[0].count == 4, p[1].count == 2, p[2].count == 2,
              p.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let y = Int(p[0]), let m = Int(p[1]), let d = Int(p[2])
        else { return false }
        return (2000...2200).contains(y) && (1...12).contains(m) && (1...31).contains(d)
    }

    static func isValidPercent(_ v: Double) -> Bool { v.isFinite && (0...1000).contains(v) }
}

/// Decides when to raise a usage alert: at 70%, 90% and 100%, only when the level rises.
/// The first reading only sets the baseline, so opening the app at 85% does not alert.
public struct AlertTracker: Equatable {
    public static let thresholds = [70, 90, 100]
    private var alerted: [Int]

    public init(windows: Int = 2) { alerted = Array(repeating: -1, count: windows) }

    /// Returns the threshold that was just crossed, if any.
    public mutating func update(window: Int, percent: Double) -> Int? {
        guard alerted.indices.contains(window), percent.isFinite else { return nil }
        let level = Self.thresholds.last { Int(percent.rounded()) >= $0 } ?? 0
        let before = alerted[window]
        alerted[window] = level
        return before >= 0 && level > before ? level : nil
    }
}
