import Foundation
import SwiftUI
import Combine

/// In-app debug log manager. Captures log messages in a circular buffer
/// so they can be viewed on-device without an Xcode connection.
///
/// Usage:
///   DebugLog.log("My message")
///   DebugLog.log("Error occurred", tag: "Camera")
///
/// Access the log view from Settings → Debug Log.
final class DebugLogManager: ObservableObject {
    static let shared = DebugLogManager()

    /// Maximum number of log entries kept in memory
    private let maxEntries = 500

    /// All log entries (newest last)
    @Published private(set) var entries: [LogEntry] = []

    private let queue = DispatchQueue(label: "com.switch2go.debuglog", qos: .utility)

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let tag: String
        let message: String
        let level: Level

        enum Level: String {
            case info = "ℹ️"
            case warn = "⚠️"
            case error = "❌"
            case debug = "🔍"
        }

        var formatted: String {
            let t = Self.formatter.string(from: timestamp)
            return "\(t) \(level.rawValue) [\(tag)] \(message)"
        }

        private static let formatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss.SSS"
            return f
        }()
    }

    private init() {}

    func log(_ message: String, tag: String = "App", level: LogEntry.Level = .info) {
        let entry = LogEntry(timestamp: Date(), tag: tag, message: message, level: level)
        // Also print to console (visible if Xcode IS connected)
        print(entry.formatted)

        queue.async { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.entries.append(entry)
                if self.entries.count > self.maxEntries {
                    self.entries.removeFirst(self.entries.count - self.maxEntries)
                }
            }
        }
    }

    func clear() {
        DispatchQueue.main.async {
            self.entries.removeAll()
        }
    }

    /// Export all entries as a single string (for sharing)
    func exportText() -> String {
        entries.map { $0.formatted }.joined(separator: "\n")
    }
}

// MARK: - Convenience global accessor

/// Shorthand for DebugLogManager.shared
enum DebugLog {
    static func log(_ message: String, tag: String = "App", level: DebugLogManager.LogEntry.Level = .info) {
        DebugLogManager.shared.log(message, tag: tag, level: level)
    }

    static func info(_ message: String, tag: String = "App") {
        DebugLogManager.shared.log(message, tag: tag, level: .info)
    }

    static func warn(_ message: String, tag: String = "App") {
        DebugLogManager.shared.log(message, tag: tag, level: .warn)
    }

    static func error(_ message: String, tag: String = "App") {
        DebugLogManager.shared.log(message, tag: tag, level: .error)
    }

    static func debug(_ message: String, tag: String = "App") {
        DebugLogManager.shared.log(message, tag: tag, level: .debug)
    }
}
