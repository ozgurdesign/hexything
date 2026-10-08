import AppKit
import CoreGraphics

enum Permissions {
    static var hasScreenRecording: Bool { CGPreflightScreenCaptureAccess() }

    private static let requestedKey = "requestedScreenRecording"

    /// macOS shows its own prompt only the first time an app asks; afterwards it only lists the app in Settings.
    static var hasRequestedBefore: Bool { UserDefaults.standard.bool(forKey: requestedKey) }

    static func request() {
        UserDefaults.standard.set(true, forKey: requestedKey)
        CGRequestScreenCaptureAccess()
    }

    static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}
