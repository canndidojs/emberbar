import AppKit
import EmberBarCore

/// Draws the menu bar text as an image so each number can have its own color
/// (SwiftUI's MenuBarExtra label ignores text colors).
///
/// The drawing handler runs every time the image is drawn, so `labelColor` follows
/// the current menu bar appearance (light/dark) without re-rendering.
enum StatusImage {
    static func make(usage: Usage?, stale: Bool, signedIn: Bool) -> NSImage {
        let font = NSFont.menuBarFont(ofSize: 0)
        let segments: [(String, NSColor)]

        if let u = usage {
            let base: NSColor = stale ? .secondaryLabelColor : .labelColor
            func color(_ percent: Double) -> NSColor {
                if stale { return base }
                switch UsageLevel(percent: percent) {
                case .normal: return base
                case .warning: return .systemOrange
                case .critical: return .systemRed
                }
            }
            segments = [
                ("5h \(Int(u.fiveHour.percent.rounded()))%", color(u.fiveHour.percent)),
                (" · ", base),
                ("W \(Int(u.week.percent.rounded()))%", color(u.week.percent)),
            ]
        } else {
            segments = [(signedIn ? "EmberBar …" : "EmberBar", .secondaryLabelColor)]
        }

        let text = NSMutableAttributedString()
        for (part, color) in segments {
            text.append(NSAttributedString(string: part, attributes: [.font: font, .foregroundColor: color]))
        }

        let size = text.size()
        let height: CGFloat = 22
        let image = NSImage(size: NSSize(width: ceil(size.width) + 2, height: height), flipped: false) { rect in
            let s = text.size()
            text.draw(at: NSPoint(x: 1, y: (rect.height - s.height) / 2))
            return true
        }
        image.isTemplate = false
        return image
    }
}
