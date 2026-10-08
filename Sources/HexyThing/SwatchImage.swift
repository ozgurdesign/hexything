import AppKit
import HexyCore

func swatchImage(_ entry: String) -> NSImage {
    NSImage(size: NSSize(width: 14, height: 14), flipped: false) { rect in
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 3, yRadius: 3)
        (ColourParser.parse(entry).map(NSColor.init) ?? .clear).setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 0.5
        path.stroke()
        return true
    }
}
