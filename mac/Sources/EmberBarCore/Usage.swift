import Foundation

public struct UsageWindow: Equatable {
    public let percent: Double
    public let resetsAt: Date?

    public init(percent: Double, resetsAt: Date?) {
        self.percent = percent
        self.resetsAt = resetsAt
    }
}

public struct Usage: Equatable {
    public let fiveHour: UsageWindow
    public let week: UsageWindow

    public init(fiveHour: UsageWindow, week: UsageWindow) {
        self.fiveHour = fiveHour
        self.week = week
    }
}

public enum UsageLevel: Equatable {
    case normal, warning, critical

    /// Normal below 70%, warning from 70%, critical from 90% (same as the Windows app).
    public init(percent: Double) {
        self = percent >= 90 ? .critical : percent >= 70 ? .warning : .normal
    }
}
