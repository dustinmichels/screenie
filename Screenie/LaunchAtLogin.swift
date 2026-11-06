import ServiceManagement
import SwiftUI

/// Registers the app itself as a login item. The system owns the state (the user can also
/// change it in System Settings → General → Login Items), so it's read back, never cached.
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

/// Footer checkbox for `LaunchAtLogin`. Re-reads the system state on every popover open and
/// after every change, so it never shows a state the system didn't accept.
struct LaunchAtLoginToggle: View {
    @State private var isOn = LaunchAtLogin.isEnabled

    var body: some View {
        Toggle("Launch at login", isOn: Binding(get: { isOn }, set: set))
            .toggleStyle(.checkbox)
            .onAppear { isOn = LaunchAtLogin.isEnabled }
    }

    private func set(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
        } catch {
            NSSound.beep()
        }
        // Turned off by the user in System Settings: registering needs their approval there.
        if enabled, SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        isOn = LaunchAtLogin.isEnabled
    }
}
