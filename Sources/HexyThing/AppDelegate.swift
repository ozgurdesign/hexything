import AppKit
import HexyCore
import KeyboardShortcuts
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let history = History()
    // LoupeController is @MainActor; the delegate is only ever used on the main thread.
    private lazy var loupe = MainActor.assumeIsolated {
        LoupeController(history: history) { [weak self] in self?.rebuildMenu() }
    }
    private var statusItem: NSStatusItem!
    /// Shown on right-click (or Control-click); a plain click starts the loupe.
    private let menu = NSMenu()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        appMenu.addItem(NSMenuItem(title: "Quit HexyThing", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        NSApp.mainMenu = mainMenu

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = NSImage(systemSymbolName: "eyedropper", accessibilityDescription: "HexyThing")
        icon?.isTemplate = true
        statusItem.button?.image = icon
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        menu.delegate = self
        rebuildMenu()

        KeyboardShortcuts.onKeyUp(for: .pickColour) { [weak self] in self?.loupe.toggle() }
        TextRecognizer.warmUp()
    }

    func menuWillOpen(_ menu: NSMenu) {
        loupe.stop()
        rebuildMenu()
    }

    @MainActor @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            // Attach the menu only for this click; with a permanent menu every click would open it.
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            loupe.toggle()
        }
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let pick = NSMenuItem(title: "Pick from screen", action: #selector(pick), keyEquivalent: "")
        pick.target = self
        // setShortcut(for:) is @MainActor; the menu is only ever rebuilt on the main thread.
        MainActor.assumeIsolated { pick.setShortcut(for: .pickColour) }
        menu.addItem(pick)
        menu.addItem(.separator())

        if history.items.isEmpty {
            let empty = NSMenuItem(title: "No colours yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for entry in history.items {
                let item = NSMenuItem(title: entry, action: #selector(copyEntry(_:)), keyEquivalent: "")
                item.target = self
                item.image = swatchImage(entry)
                item.representedObject = entry
                item.attributedTitle = NSAttributedString(
                    string: entry,
                    attributes: [.font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)]
                )
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        let clear = NSMenuItem(title: "Clear history", action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        clear.isEnabled = !history.items.isEmpty
        menu.addItem(clear)
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let about = NSMenuItem(title: "About HexyThing", action: #selector(about), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func pick() {
        // Let the menu close before the overlays take the screen.
        DispatchQueue.main.async { self.loupe.toggle() }
    }

    @objc private func copyEntry(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry, forType: .string)
    }

    @objc private func clearHistory() {
        history.clear()
        rebuildMenu()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = "HexyThing Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func about() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
