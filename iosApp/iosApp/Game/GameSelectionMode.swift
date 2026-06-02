import Foundation

/// Selection modes that can arm and play phrase games.
enum GameSelectionMode {
    static let supportedModes: Set<String> = ["eyeGaze", "face", "none"]

    static func supportsGames(selectionMode: String) -> Bool {
        supportedModes.contains(selectionMode)
    }

    static func usesGaze(selectionMode: String) -> Bool {
        selectionMode == "eyeGaze" || selectionMode == "face"
    }

    static func usesTouch(selectionMode: String) -> Bool {
        selectionMode == "none"
    }

    static func unsupportedMessage(selectionMode: String) -> String {
        switch selectionMode {
        case "armRaise":
            return "Games are not available in arm raise mode. Switch to eye gaze, head tracking, or touch only in Settings → Selection Mode."
        case "handGesture":
            return "Games are not available in hand gesture mode. Switch to eye gaze, head tracking, or touch only in Settings → Selection Mode."
        default:
            return "Games are not available in this selection mode. Switch to eye gaze, head tracking, or touch only in Settings → Selection Mode."
        }
    }
}
