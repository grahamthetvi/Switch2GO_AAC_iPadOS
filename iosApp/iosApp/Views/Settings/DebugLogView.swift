import SwiftUI

/// In-app debug log viewer. Shows recent log messages with live updates,
/// color-coded by level, with filtering and share/copy support.
struct DebugLogView: View {
    @StateObject private var settings = AppSettings.shared
    @ObservedObject private var logManager = DebugLogManager.shared
    @State private var filterTag: String = "All"
    @State private var autoScroll = true
    @State private var showShareSheet = false
    @State private var searchText = ""

    private var allTags: [String] {
        let tags = Set(logManager.entries.map { $0.tag })
        return ["All"] + tags.sorted()
    }

    private var filteredEntries: [DebugLogManager.LogEntry] {
        logManager.entries.filter { entry in
            let tagMatch = filterTag == "All" || entry.tag == filterTag
            let searchMatch = searchText.isEmpty ||
                entry.message.localizedCaseInsensitiveContains(searchText) ||
                entry.tag.localizedCaseInsensitiveContains(searchText)
            return tagMatch && searchMatch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(allTags, id: \.self) { tag in
                        Button {
                            filterTag = tag
                        } label: {
                            Text(tag)
                                .font(.caption)
                                .fontWeight(filterTag == tag ? .bold : .regular)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(filterTag == tag ? Color.blue : Color(UIColor.tertiarySystemBackground))
                                .foregroundColor(filterTag == tag ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(UIColor.secondarySystemBackground))

            Divider()

            // Log entries
            if filteredEntries.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No log entries")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Logs will appear here as tracking runs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(filteredEntries) { entry in
                                logEntryRow(entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .onChange(of: logManager.entries.count) { _, _ in
                        if autoScroll, let last = filteredEntries.last {
                            withAnimation(.easeOut(duration: 0.1)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .background(settings.appBorderColor)
        .environment(\.colorScheme, settings.preferredColorScheme)
        .searchable(text: $searchText, prompt: "Filter logs...")
        .navigationTitle("Debug Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Auto-scroll toggle
                Button {
                    autoScroll.toggle()
                } label: {
                    Image(systemName: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle")
                        .foregroundColor(autoScroll ? .blue : .secondary)
                }
                .accessibilityLabel(autoScroll ? "Auto-scroll on" : "Auto-scroll off")

                // Share / Copy
                Menu {
                    Button {
                        UIPasteboard.general.string = logManager.exportText()
                    } label: {
                        Label("Copy All to Clipboard", systemImage: "doc.on.doc")
                    }

                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Share Log...", systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Button(role: .destructive) {
                        logManager.clear()
                    } label: {
                        Label("Clear Log", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showShareSheet) {
            let text = logManager.exportText()
            ShareSheet(items: [text])
        }
    }

    private func logEntryRow(_ entry: DebugLogManager.LogEntry) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(entry.level.rawValue)
                .font(.caption2)

            Text(timeString(entry.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 75, alignment: .leading)

            Text("[\(entry.tag)]")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(tagColor(entry.tag))
                .frame(width: 90, alignment: .leading)
                .lineLimit(1)

            Text(entry.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(levelColor(entry.level))
                .lineLimit(3)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            entry.level == .error ? Color.red.opacity(0.08) :
            entry.level == .warn ? Color.orange.opacity(0.06) :
            Color.clear
        )
        .cornerRadius(4)
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: date)
    }

    private func tagColor(_ tag: String) -> Color {
        switch tag {
        case "Camera": return .purple
        case "EyeGaze": return .green
        case "HeadTrack": return .orange
        case "MediaPipe": return .pink
        case "Dwell": return .cyan
        case "Orientation": return .yellow
        case "Switch": return .mint
        case "Tracking": return .indigo
        default: return .blue
        }
    }

    private func levelColor(_ level: DebugLogManager.LogEntry.Level) -> Color {
        switch level {
        case .info: return .primary
        case .warn: return .orange
        case .error: return .red
        case .debug: return .secondary
        }
    }
}

/// Simple UIKit share sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
