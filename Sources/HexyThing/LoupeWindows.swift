import AppKit
import SwiftUI

/// Floating loupe that follows the cursor. Ignores the mouse; the overlays handle input.
final class LoupePanel: NSPanel {
    private static let offset: CGFloat = 16

    init(model: LoupeModel) {
        super.init(contentRect: CGRect(origin: .zero, size: LoupeView.size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = NSHostingView(rootView: LoupeView(model: model))
    }

    /// Places the loupe below-right of the cursor, flipping near screen edges.
    func follow(_ point: CGPoint) {
        guard let screen = NSScreen.containing(point) else { return }
        let bounds = screen.visibleFrame
        let size = LoupeView.size
        var x = point.x + Self.offset
        var y = point.y - Self.offset - size.height
        if x + size.width > bounds.maxX { x = point.x - Self.offset - size.width }
        if y < bounds.minY { y = point.y + Self.offset }
        setFrameOrigin(CGPoint(x: x, y: y))
    }
}

@MainActor
protocol OverlayHandler: AnyObject {
    func overlayMouseMoved()
    func overlayClicked()
    func overlayCancelled()
    func overlayModifiersChanged()
}

/// Near-invisible full-screen panel that swallows clicks while the loupe is active.
final class OverlayPanel: NSPanel {
    init(screen: NSScreen, handler: OverlayHandler) {
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .screenSaver
        isOpaque = false
        // Fully clear windows let clicks through. A near-zero alpha may round to fully clear in an
        // 8-bit backing store, which would let clicks through, so use a value that survives rounding.
        backgroundColor = NSColor(white: 0, alpha: 0.01)
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = OverlayView(handler: handler)
        contentView = view
        initialFirstResponder = view
    }

    override var canBecomeKey: Bool { true }
}

private final class OverlayView: NSView {
    weak var handler: OverlayHandler?

    init(handler: OverlayHandler) {
        self.handler = handler
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        installTrackingArea()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installTrackingArea()
    }

    private func installTrackingArea() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override func mouseMoved(with event: NSEvent) { handler?.overlayMouseMoved() }
    override func mouseDragged(with event: NSEvent) { handler?.overlayMouseMoved() }
    override func mouseDown(with event: NSEvent) { handler?.overlayClicked() }
    override func flagsChanged(with event: NSEvent) { handler?.overlayModifiersChanged() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { handler?.overlayCancelled() } // Esc
    }
}
