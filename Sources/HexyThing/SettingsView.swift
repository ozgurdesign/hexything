import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Pick from screen:", name: .pickColour)
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
        }
        .padding(20)
        .frame(width: 340)
    }
}
