import AppKit
import HexyCore

@MainActor
final class LoupeController: OverlayHandler {
    private let history: History
    private let onSave: () -> Void
    private let reader = ScreenReader()
    private let model = LoupeModel()
    private lazy var loupe = LoupePanel(model: model)
    private var overlays: [OverlayPanel] = []

    private var busy = false
    private var pending: CGPoint?
    private var session = 0

    private var previousApp: NSRunningApplication?

    private(set) var isActive = false

    init(history: History, onSave: @escaping () -> Void) {
        self.history = history
        self.onSave = onSave
    }

    func toggle() {
        isActive ? stop() : start()
    }

    private func start() {
        guard Permissions.hasScreenRecording else {
            showPermissionAlert()
            return
        }
        isActive = true
        session += 1
        let current = session
        model.capture = nil
        model.match = nil
        model.optionHeld = NSEvent.modifierFlags.contains(.option)

        let front = NSWorkspace.shared.frontmostApplication
        previousApp = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front

        overlays = NSScreen.screens.map { OverlayPanel(screen: $0, handler: self) }
        overlays.forEach { $0.orderFrontRegardless() }
        NSApp.activate(ignoringOtherApps: true)
        let mouseScreen = NSScreen.containing(NSEvent.mouseLocation)
        if let overlay = overlays.first(where: { $0.screen == mouseScreen }) {
            overlay.makeKey()
            overlay.makeFirstResponder(overlay.contentView)
        }

        let point = NSEvent.mouseLocation
        loupe.follow(point)
        loupe.orderFrontRegardless()

        Task { @MainActor in
            do {
                try await reader.refresh()
            } catch {
                guard self.session == current, self.isActive else { return }
                self.stop()
                self.showCaptureError(error)
                return
            }
            guard self.session == current, self.isActive else { return }
            self.request(NSEvent.mouseLocation)
        }
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        session += 1
        pending = nil
        loupe.orderOut(nil)
        overlays.forEach { $0.orderOut(nil) }
        overlays = []
        if let previousApp {
            NSApp.yieldActivation(to: previousApp)
            previousApp.activate()
        } else {
            NSApp.hide(nil)
        }
        previousApp = nil
    }

    // MARK: OverlayHandler

    func overlayMouseMoved() {
        let point = NSEvent.mouseLocation
        loupe.follow(point)
        request(point)
    }

    func overlayClicked() {
        guard let text = model.match?.text else { return }
        history.add(text)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        stop()
        onSave()
    }

    /// ⌥ switches bare triplets between RGB and HSL; re-read straight away rather than on the next mouse move.
    func overlayModifiersChanged() {
        let held = NSEvent.modifierFlags.contains(.option)
        guard held != model.optionHeld else { return }
        model.optionHeld = held
        request(NSEvent.mouseLocation)
    }

    func overlayCancelled() {
        stop()
    }

    // MARK: Pipeline

    /// One recognition in flight; newer cursor positions replace any queued one.
    private func request(_ point: CGPoint) {
        guard isActive else { return }
        if busy {
            pending = point
            return
        }
        busy = true
        let current = session
        let bareAsHSL = model.optionHeld
        Task { @MainActor in
            let capture = try? await reader.capture(around: point)
            var match: ColourMatch?
            if let capture {
                match = await Task.detached(priority: .userInitiated) {
                    let aspect = CGFloat(capture.image.width) / CGFloat(capture.image.height)
                    let lines = LineMerger.merge(TextRecognizer.recognize(capture.image), aspect: aspect)
                    return ColourFinder.nearest(in: lines, to: capture.cursor, bareAsHSL: bareAsHSL)
                }.value
            }
            self.busy = false
            guard self.session == current, self.isActive else { return }
            self.model.capture = capture
            let oldText = self.model.match?.text
            self.model.match = match
            if let newText = match?.text, newText != oldText {
                NSAccessibility.post(
                    element: NSApplication.shared,
                    notification: .announcementRequested,
                    userInfo: [.announcement: newText, .priority: NSAccessibilityPriorityLevel.high.rawValue]
                )
            }
            if let next = self.pending {
                self.pending = nil
                self.request(next)
            }
        }
    }

    private func showPermissionAlert() {
        // First time: macOS shows its own prompt, so don't stack ours on top of it.
        guard Permissions.hasRequestedBefore else {
            Permissions.request()
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "HexyThing needs Screen Recording permission"
        alert.informativeText = "It reads the text under your cursor to find colour codes. Recognition runs on your Mac and nothing is stored except the colours you save. After allowing it, quit and reopen HexyThing."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            Permissions.openSettings()
        }
    }

    private func showCaptureError(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "HexyThing can't read the screen"
        alert.informativeText = "macOS refused the screen capture (\(error.localizedDescription)). If HexyThing was rebuilt or updated, remove it from Screen Recording in System Settings, then allow it again."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            Permissions.openSettings()
        }
    }
}
