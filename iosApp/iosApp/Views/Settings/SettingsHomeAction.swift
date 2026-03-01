import SwiftUI

/// Environment action to dismiss the entire Settings flow back to the main screen.
struct SettingsHomeActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var settingsHomeAction: (() -> Void)? {
        get { self[SettingsHomeActionKey.self] }
        set { self[SettingsHomeActionKey.self] = newValue }
    }
}
