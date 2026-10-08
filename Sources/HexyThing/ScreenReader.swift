import AppKit
import ScreenCaptureKit

struct Capture {
    let image: CGImage
    /// Cursor position inside the image, normalized 0…1, origin bottom-left (Vision convention).
    let cursor: CGPoint
}

enum ScreenReaderError: Error { case noDisplay }

@MainActor
final class ScreenReader {
    static let stripSize = CGSize(width: 320, height: 80)

    private var content: SCShareableContent?

    /// Call when a loupe session starts; display list and own-app exclusion are cached for the session.
    func refresh() async throws {
        // Drop the previous session's cache so a failure surfaces instead of reusing stale displays.
        content = nil
        content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    }

    func capture(around point: CGPoint) async throws -> Capture {
        guard let content,
              let screen = NSScreen.containing(point),
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let display = content.displays.first(where: { $0.displayID == number })
        else { throw ScreenReaderError.noDisplay }

        let own = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: own, exceptingWindows: [])

        // Cursor in display-local points, origin top-left (ScreenCaptureKit convention).
        let local = CGPoint(x: point.x - screen.frame.minX, y: screen.frame.maxY - point.y)
        let size = Self.stripSize
        let origin = CGPoint(
            x: min(max(local.x - size.width / 2, 0), screen.frame.width - size.width),
            y: min(max(local.y - size.height / 2, 0), screen.frame.height - size.height)
        )
        let rect = CGRect(origin: origin, size: size)

        let config = SCStreamConfiguration()
        config.sourceRect = rect
        config.width = Int(size.width * screen.backingScaleFactor)
        config.height = Int(size.height * screen.backingScaleFactor)
        config.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        let cursor = CGPoint(
            x: (local.x - rect.minX) / size.width,
            y: 1 - (local.y - rect.minY) / size.height
        )
        return Capture(image: image, cursor: cursor)
    }
}

extension NSScreen {
    /// Screen under a global AppKit point. NSMouseInRect covers the top edge; the nearest-screen fallback covers the right edge and points just off-screen.
    static func containing(_ point: CGPoint) -> NSScreen? {
        if let hit = screens.first(where: { NSMouseInRect(point, $0.frame, false) }) { return hit }
        func distance(_ r: CGRect) -> CGFloat {
            let dx = max(r.minX - point.x, 0, point.x - r.maxX)
            let dy = max(r.minY - point.y, 0, point.y - r.maxY)
            return hypot(dx, dy)
        }
        return screens.min(by: { distance($0.frame) < distance($1.frame) })
    }
}
