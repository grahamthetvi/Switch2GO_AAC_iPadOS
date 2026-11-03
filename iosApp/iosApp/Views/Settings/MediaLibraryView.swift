import AVFoundation
import AVKit
import ImageIO
import SwiftUI

enum MediaLibraryFilter: String, CaseIterable, Identifiable {
    case all
    case pictures
    case videos
    case audio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return L("All")
        case .pictures:
            return L("Pictures")
        case .videos:
            return L("Videos")
        case .audio:
            return L("Audio")
        }
    }
}

final class MediaLibraryModel: ObservableObject {
    @Published private(set) var items: [MediaLibraryItem] = []
    @Published private(set) var isLoading = true
    @Published var errorMessage: String?

    func reload() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let loaded = MediaLibraryStore.loadItems()
            DispatchQueue.main.async {
                self?.items = loaded
                self?.isLoading = false
            }
        }
    }

    func items(matching filter: MediaLibraryFilter) -> [MediaLibraryItem] {
        switch filter {
        case .all:
            return items
        case .pictures:
            return items.filter { $0.kind == .picture }
        case .videos:
            return items.filter { $0.kind == .video }
        case .audio:
            return items.filter { $0.kind == .audio }
        }
    }
}

struct MediaLibraryView: View {
    @StateObject private var model = MediaLibraryModel()
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    @State private var filter: MediaLibraryFilter = .all

    var body: some View {
        List {
            Section {
                Text(l10n: "Pictures, videos, and audio you add here, or attach to a phrase, stay in this library. A shared category or a restored backup shows up here too, so you can save a copy or use the file on another phrase.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section {
                Picker(L("Show"), selection: $filter) {
                    ForEach(MediaLibraryFilter.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                if model.isLoading && model.items.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if visibleItems.isEmpty {
                    Text(emptyMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(visibleItems) { item in
                        NavigationLink {
                            MediaLibraryDetailView(relativePath: item.relativePath)
                        } label: {
                            MediaLibraryRow(item: item)
                        }
                        .accessibilityLabel(accessibilityLabel(for: item))
                    }
                }
            }
        }
        .modifier(MediaLibraryChrome(settings: settings))
        .navigationTitle(Text(l10n: "Media Library"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { settingsHomeAction?() ?? dismiss() }) {
                    Label(L("Home"), systemImage: "house.fill")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                MediaLibraryAddControl(kinds: [.picture, .video, .audio]) {
                    model.reload()
                } onError: { message in
                    model.errorMessage = message
                }
            }
        }
        .alert(L("Could not add file"), isPresented: errorPresented) {
            Button(L("OK"), role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
        .environmentObject(model)
        .onAppear { model.reload() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PhrasesUpdated"))) { _ in
            model.reload()
        }
    }

    private var visibleItems: [MediaLibraryItem] {
        model.items(matching: filter)
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }

    private var emptyMessage: String {
        switch filter {
        case .all:
            return L("Nothing here yet. Add a picture, video, or audio file, or attach one to a phrase.")
        case .pictures:
            return L("No pictures yet.")
        case .videos:
            return L("No videos yet.")
        case .audio:
            return L("No audio yet.")
        }
    }

    private func accessibilityLabel(for item: MediaLibraryItem) -> String {
        "\(kindName(item.kind)), \(itemTitle(item)), \(usageSummary(item))"
    }
}

struct MediaLibraryDetailView: View {
    let relativePath: String

    @EnvironmentObject private var model: MediaLibraryModel
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    @State private var shareURL: URL?
    @State private var showingShare = false
    @State private var showingRemoveConfirm = false
    @State private var statusMessage: String?
    @State private var shareError: String?

    private var item: MediaLibraryItem? {
        model.items.first { $0.relativePath == relativePath }
    }

    var body: some View {
        List {
            if let item {
                Section {
                    MediaLibraryPreview(item: item)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 180)
                    Text(itemTitle(item))
                        .font(.title3.weight(.semibold))
                    Text(metaLine(item))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(usageSummary(item))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let statusMessage {
                        Text(statusMessage)
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }

                Section {
                    Button {
                        share(item)
                    } label: {
                        Label(L("Save or Share"), systemImage: "square.and.arrow.up")
                    }
                    .accessibilityHint(L("Save a copy to Files, Mail, or AirDrop"))

                    NavigationLink {
                        MediaLibraryPhraseChooser(item: item, statusMessage: $statusMessage)
                    } label: {
                        Label(L("Use on a Phrase"), systemImage: "arrow.triangle.branch")
                    }
                }

                if !item.usages.isEmpty {
                    Section(L("Used by")) {
                        ForEach(item.usages) { usage in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(usage.phraseText)
                                    .font(.body)
                                Text(usage.categoryName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingRemoveConfirm = true
                    } label: {
                        Label(L("Remove from Library"), systemImage: "trash")
                    }
                }
            } else if model.isLoading {
                ProgressView()
            }
        }
        .modifier(MediaLibraryChrome(settings: settings))
        .navigationTitle(Text(l10n: "Library File"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { settingsHomeAction?() ?? dismiss() }) {
                    Label(L("Home"), systemImage: "house.fill")
                }
            }
        }
        .alert(L("Remove from Library?"), isPresented: $showingRemoveConfirm) {
            Button(L("Cancel"), role: .cancel) {}
            Button(L("Remove"), role: .destructive) {
                let path = relativePath
                DispatchQueue.global(qos: .userInitiated).async {
                    MediaLibraryStore.remove(relativePath: path)
                }
            }
        } message: {
            Text(removeMessage)
        }
        .alert(L("Could not share file"), isPresented: Binding(
            get: { shareError != nil },
            set: { if !$0 { shareError = nil } }
        )) {
            Button(L("OK"), role: .cancel) {}
        } message: {
            Text(shareError ?? "")
        }
        .sheet(isPresented: $showingShare, onDismiss: { shareURL = nil }) {
            if let shareURL {
                ShareSheet(items: [shareURL])
            }
        }
        .onChange(of: model.items.map(\.relativePath)) { _, paths in
            if !model.isLoading && !paths.contains(relativePath) {
                dismiss()
            }
        }
    }

    private var removeMessage: String {
        guard let item else { return L("This file will be deleted from the iPad.") }
        let names = item.usages.map(\.phraseText).filter { !$0.isEmpty }
        if names.isEmpty {
            return L("This file will be deleted from the iPad.")
        }
        var list = names.prefix(4).joined(separator: ", ")
        if names.count > 4 {
            list += " +\(names.count - 4)"
        }
        return L("It will also be removed from: %@", list)
    }

    private func metaLine(_ item: MediaLibraryItem) -> String {
        let ext = item.fileExtension.isEmpty ? kindName(item.kind) : item.fileExtension.uppercased()
        let size = ByteCountFormatter.string(fromByteCount: item.byteSize, countStyle: .file)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "\(ext) · \(size) · \(formatter.string(from: item.modifiedAt))"
    }

    private func share(_ item: MediaLibraryItem) {
        guard let url = MediaStorage.resolveURL(mediaRef: item.relativePath) else {
            shareError = L("Could not find this file.")
            return
        }
        shareURL = url
        showingShare = true
    }
}

private struct MediaLibraryPhraseChooser: View {
    let item: MediaLibraryItem
    @Binding var statusMessage: String?

    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    @State private var destinations: [MediaLibraryDestination] = []
    @State private var isLoading = true
    @State private var isAttaching = false
    @State private var attachError: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if destinations.isEmpty {
                Text(l10n: "Add a phrase in Edit Categories before you can reuse this file.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List(destinations) { category in
                    NavigationLink {
                        phraseList(category)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.categoryName)
                                .font(.body)
                            if category.isHidden {
                                Text(l10n: "Hidden")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .modifier(MediaLibraryChrome(settings: settings))
        .navigationTitle(Text(l10n: "Use on a Phrase"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { settingsHomeAction?() ?? dismiss() }) {
                    Label(L("Home"), systemImage: "house.fill")
                }
            }
        }
        .overlay {
            if isAttaching {
                ProgressView(L("Adding…"))
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert(L("Could not add to phrase"), isPresented: Binding(
            get: { attachError != nil },
            set: { if !$0 { attachError = nil } }
        )) {
            Button(L("OK"), role: .cancel) {}
        } message: {
            Text(attachError ?? "")
        }
        .onAppear(perform: load)
    }

    private func phraseList(_ category: MediaLibraryDestination) -> some View {
        List(category.phrases) { phrase in
            Button {
                attach(phrase)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(phrase.phraseText)
                            .font(.body)
                            .foregroundColor(.primary)
                        if phrase.alreadyUsesFile {
                            Text(l10n: "Already on this phrase")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if phrase.alreadyUsesFile {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .disabled(isAttaching || phrase.alreadyUsesFile)
        }
        .modifier(MediaLibraryChrome(settings: settings))
        .navigationTitle(category.categoryName)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isAttaching {
                ProgressView(L("Adding…"))
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func load() {
        let path = item.relativePath
        let kind = item.kind
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = MediaLibraryStore.destinations(for: path, kind: kind)
            DispatchQueue.main.async {
                destinations = loaded
                isLoading = false
            }
        }
    }

    private func attach(_ phrase: MediaLibraryDestinationPhrase) {
        isAttaching = true
        let path = item.relativePath
        let kind = item.kind
        DispatchQueue.global(qos: .userInitiated).async {
            let result = MediaLibraryStore.attach(
                relativePath: path,
                kind: kind,
                phraseId: phrase.phraseId,
                isPreset: phrase.isPreset
            )
            DispatchQueue.main.async {
                isAttaching = false
                switch result {
                case .attached:
                    statusMessage = L("Added to %@", phrase.phraseText)
                    dismiss()
                case .alreadyAttached:
                    statusMessage = L("Already used by %@", phrase.phraseText)
                    dismiss()
                case .missingPhrase:
                    attachError = L("That phrase is no longer on this iPad.")
                }
            }
        }
    }
}

struct MediaLibraryRow: View {
    let item: MediaLibraryItem

    var body: some View {
        HStack(spacing: 12) {
            MediaLibraryThumbnail(item: item, maxPixel: 160)
            VStack(alignment: .leading, spacing: 4) {
                Text(itemTitle(item))
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Text(usageSummary(item))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MediaLibraryThumbnail: View {
    let item: MediaLibraryItem
    var maxPixel: CGFloat = 160

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: kindSymbol(item.kind))
                    .font(.title2)
                    .foregroundColor(kindColor(item.kind))
            }
        }
        .frame(width: 64, height: 64)
        .background(Color(UIColor.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: item.relativePath) {
            let path = item.relativePath
            let kind = item.kind
            let pixels = maxPixel
            let loaded = await Task.detached(priority: .userInitiated) {
                MediaLibraryThumbnailLoader.image(relativePath: path, kind: kind, maxPixel: pixels)
            }.value
            image = loaded
        }
    }
}

private struct MediaLibraryPreview: View {
    let item: MediaLibraryItem

    @State private var image: UIImage?
    @State private var player: AVPlayer?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingAudio = false

    var body: some View {
        VStack(spacing: 12) {
            preview
            if item.kind == .audio {
                Button {
                    toggleAudio()
                } label: {
                    Label(
                        isPlayingAudio ? L("Stop") : L("Play"),
                        systemImage: isPlayingAudio ? "stop.fill" : "play.fill"
                    )
                    .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(isPlayingAudio ? L("Stop") : L("Play"))
            }
        }
        .task(id: item.relativePath) {
            await loadStill()
        }
        .onDisappear {
            player?.pause()
            audioPlayer?.stop()
            isPlayingAudio = false
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch item.kind {
        case .picture:
            still
        case .video:
            if let player {
                VideoPlayer(player: player)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ZStack {
                    still
                    Button {
                        startVideo()
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("Play"))
                }
            }
        case .audio:
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundColor(.teal)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
        }
    }

    @ViewBuilder
    private var still: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 240)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            Image(systemName: kindSymbol(item.kind))
                .font(.system(size: 48))
                .foregroundColor(kindColor(item.kind))
                .frame(maxWidth: .infinity)
                .frame(height: 120)
        }
    }

    private func loadStill() async {
        let path = item.relativePath
        let kind = item.kind
        let loaded = await Task.detached(priority: .userInitiated) {
            MediaLibraryThumbnailLoader.image(relativePath: path, kind: kind, maxPixel: 800)
        }.value
        image = loaded
    }

    private func startVideo() {
        guard let url = MediaStorage.resolveURL(mediaRef: item.relativePath) else { return }
        let player = AVPlayer(url: url)
        self.player = player
        player.play()
    }

    private func toggleAudio() {
        if isPlayingAudio {
            audioPlayer?.stop()
            isPlayingAudio = false
            return
        }
        guard let url = MediaStorage.resolveURL(mediaRef: item.relativePath),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        audioPlayer = player
        player.play()
        isPlayingAudio = true
    }
}

private struct MediaLibraryChrome: ViewModifier {
    @ObservedObject var settings: AppSettings

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(settings.appBorderColor)
            .environment(\.colorScheme, settings.preferredColorScheme)
            .toolbarBackground(settings.appBorderColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

enum MediaLibraryThumbnailLoader {
    static func image(relativePath: String, kind: MediaLibraryKind, maxPixel: CGFloat) -> UIImage? {
        guard let url = MediaStorage.resolveURL(mediaRef: relativePath) else { return nil }
        switch kind {
        case .picture:
            return downsample(url: url, maxPixel: maxPixel)
        case .video:
            guard let data = VideoPosterGenerator.jpegPoster(from: url, maxDimension: maxPixel) else { return nil }
            return UIImage(data: data)
        case .audio:
            return nil
        }
    }

    private static func downsample(url: URL, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
            return UIImage(contentsOfFile: url.path)
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            return UIImage(contentsOfFile: url.path)
        }
        return UIImage(cgImage: cgImage)
    }
}

func itemTitle(_ item: MediaLibraryItem) -> String {
    if let usage = item.usages.first(where: { !$0.phraseText.isEmpty }) {
        if item.usages.count > 1 {
            return L("%@ +%@", usage.phraseText, "\(item.usages.count - 1)")
        }
        return usage.phraseText
    }
    return kindName(item.kind)
}

func usageSummary(_ item: MediaLibraryItem) -> String {
    let names = item.usages.map(\.phraseText).filter { !$0.isEmpty }
    if names.isEmpty { return L("Not used by a phrase yet") }
    if names.count == 1 { return L("Used by %@", names[0]) }
    return L("Used by %@ phrases", "\(names.count)")
}

func kindName(_ kind: MediaLibraryKind) -> String {
    switch kind {
    case .picture:
        return L("Picture")
    case .video:
        return L("Video")
    case .audio:
        return L("Audio")
    }
}

func kindSymbol(_ kind: MediaLibraryKind) -> String {
    switch kind {
    case .picture:
        return "photo"
    case .video:
        return "film"
    case .audio:
        return "waveform"
    }
}

func kindColor(_ kind: MediaLibraryKind) -> Color {
    switch kind {
    case .picture:
        return .purple
    case .video:
        return .indigo
    case .audio:
        return .teal
    }
}
