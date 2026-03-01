import SwiftUI

/// Accessibility helpers and extensions
extension View {
    /// Add comprehensive accessibility labels
    func accessibleButton(label: String, hint: String? = nil, traits: AccessibilityTraits = .isButton) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }
    
    /// Add Dynamic Type support with custom scaling
    func dynamicTypeSize(min: DynamicTypeSize = .xSmall, max: DynamicTypeSize = .xxxLarge) -> some View {
        self.dynamicTypeSize(min...max)
    }
}

/// VoiceOver announcement helper
func announceForAccessibility(_ message: String) {
    UIAccessibility.post(notification: .announcement, argument: message)
}

/// Check if VoiceOver is running
var isVoiceOverRunning: Bool {
    UIAccessibility.isVoiceOverRunning
}

/// Check if Switch Control is running
var isSwitchControlRunning: Bool {
    UIAccessibility.isSwitchControlRunning
}
