import Foundation

public enum TimeText {
    /// "45min", "2h 15min", "3d 4h". Rounds down; never negative.
    public static func remaining(_ interval: TimeInterval, lang: Lang = L.current) -> String {
        let minutes = max(0, Int(interval / 60))
        let min = L.t("unit.min", in: lang), h = L.t("unit.h", in: lang), d = L.t("unit.d", in: lang)
        if minutes < 60 { return "\(minutes)\(min)" }
        let hours = minutes / 60
        if hours < 24 { return minutes % 60 == 0 ? "\(hours)\(h)" : "\(hours)\(h) \(minutes % 60)\(min)" }
        let days = hours / 24
        return hours % 24 == 0 ? "\(days)\(d)" : "\(days)\(d) \(hours % 24)\(h)"
    }

    /// Reset moment: time only when it is today, otherwise weekday + time, in the user's locale.
    public static func resetLabel(_ date: Date, now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.setLocalizedDateFormatFromTemplate(calendar.isDate(date, inSameDayAs: now) ? "jmm" : "EEEjmm")
        return f.string(from: date)
    }
}
