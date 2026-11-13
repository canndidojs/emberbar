import AppKit
import Charts
import EmberBarCore
import SwiftUI

struct HistoryView: View {
    @ObservedObject var recorder: Recorder
    @ObservedObject var settings: Settings

    private struct Point: Identifiable {
        let id = UUID()
        let label: String
        let series: String
        let value: Double
    }

    private var months: [MonthUsage] { recorder.history.monthly(6) }

    private var monthLabel: (Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: settings.language.rawValue)
        f.setLocalizedDateFormatFromTemplate("MMMyy")
        return { f.string(from: $0) }
    }

    var body: some View {
        let five = L.t("hist.five"), week = L.t("hist.week")
        let label = monthLabel
        let points: [Point] = months.flatMap { m -> [Point] in
            var out: [Point] = []
            if let v = m.avg5 { out.append(Point(label: label(m.month), series: five, value: v)) }
            if let v = m.maxWeek { out.append(Point(label: label(m.month), series: week, value: v)) }
            return out
        }
        let dayCounts = Dictionary(months.map { (label($0.month), $0.days) }, uniquingKeysWith: { first, _ in first })

        VStack(spacing: 14) {
            Text(L.t("hist.title")).font(.title2.weight(.semibold))
            Text(L.t("hist.sub")).font(.subheadline).foregroundStyle(.secondary)

            if points.isEmpty {
                Text(L.t("hist.empty")).foregroundStyle(.secondary).frame(maxHeight: .infinity)
            } else {
                Chart(points) { p in
                    BarMark(x: .value("Month", p.label), y: .value("%", p.value))
                        .foregroundStyle(by: .value("Series", p.series))
                        .position(by: .value("Series", p.series))
                        .annotation(position: .top) {
                            Text("\(Int(p.value.rounded()))%").font(.caption2).foregroundStyle(.secondary)
                        }
                }
                .chartForegroundStyleScale([five: Color.orange, week: Color(red: 0.59, green: 0.66, blue: 0.80)])
                .chartYScale(domain: 0...100)
                .chartYAxis { AxisMarks(values: [0, 50, 100]) { AxisGridLine(); AxisValueLabel() } }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let name = value.as(String.self) {
                                VStack(spacing: 2) {
                                    Text(name)
                                    Text(daysText(dayCounts[name] ?? 0)).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .chartLegend(position: .top, alignment: .leading)
                .frame(height: 230)
            }

            Text(L.t("hist.note")).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)

            HStack {
                Button(L.t("hist.clear")) { confirmClear() }
                Spacer()
            }
        }
        .padding(24)
        .frame(width: 560, height: 470)
    }

    private func daysText(_ n: Int) -> String {
        n == 0 ? "—" : n == 1 ? L.t("hist.day") : L.t("hist.days", n)
    }

    private func confirmClear() {
        let alert = NSAlert()
        alert.messageText = L.t("hist.clearask")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L.t("hist.clear"))
        alert.addButton(withTitle: L.t("common.cancel"))
        if alert.runModal() == .alertFirstButtonReturn { recorder.clear() }
    }
}

@MainActor
enum HistoryWindow {
    private static var window: NSWindow?

    static func show(recorder: Recorder, settings: Settings) {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
        } else {
            let w = NSWindow(contentViewController: NSHostingController(rootView: HistoryView(recorder: recorder, settings: settings)))
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
            w.makeKeyAndOrderFront(nil)
        }
        window?.title = L.t("hist.title")
        NSApp.activate(ignoringOtherApps: true)
    }
}
