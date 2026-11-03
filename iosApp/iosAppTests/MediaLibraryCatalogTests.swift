import XCTest
@testable import iosApp

final class MediaLibraryCatalogTests: XCTestCase {
    func testKindClassificationSkipsGeneratedStills() {
        XCTAssertEqual(MediaLibraryCatalog.kind(forRelativePath: "Images/custom_image_a.jpg"), .picture)
        XCTAssertEqual(MediaLibraryCatalog.kind(forRelativePath: "Images/custom_image_a.PNG"), .picture)
        XCTAssertEqual(MediaLibraryCatalog.kind(forRelativePath: "Media/clip.mp4"), .video)
        XCTAssertEqual(MediaLibraryCatalog.kind(forRelativePath: "Media/clip.MOV"), .video)
        XCTAssertEqual(MediaLibraryCatalog.kind(forRelativePath: "Media/voice.m4a"), .audio)
        XCTAssertEqual(MediaLibraryCatalog.kind(forRelativePath: "Media/voice.wav"), .audio)
        XCTAssertNil(MediaLibraryCatalog.kind(forRelativePath: "Images/video_poster_abc.jpg"))
        XCTAssertNil(MediaLibraryCatalog.kind(forRelativePath: "Media/notes.bin"))
        XCTAssertNil(MediaLibraryCatalog.kind(forRelativePath: "emoji:😀"))
        XCTAssertNil(MediaLibraryCatalog.kind(forRelativePath: "youtube:abc"))
    }

    func testBuildListsUnusedFilesAndSharedUse() {
        let older = Date(timeIntervalSince1970: 10)
        let newer = Date(timeIntervalSince1970: 20)
        let files = [
            MediaLibraryFileSnapshot(relativePath: "Images/custom_image_a.jpg", byteSize: 10, modifiedAt: older),
            MediaLibraryFileSnapshot(relativePath: "Media/clip.mp4", byteSize: 20, modifiedAt: newer),
            MediaLibraryFileSnapshot(relativePath: "Media/clip.mp4", byteSize: 20, modifiedAt: newer),
            MediaLibraryFileSnapshot(relativePath: "Images/video_poster_a.jpg", byteSize: 5, modifiedAt: newer),
            MediaLibraryFileSnapshot(relativePath: "Media/voice.m4a", byteSize: 8, modifiedAt: older)
        ]
        let phrases = [
            phrase("p1", text: "Juice", image: "Images/custom_image_a.jpg", media: "Media/clip.mp4"),
            phrase("p1", text: "Juice", image: "Images/custom_image_a.jpg", media: "Media/clip.mp4"),
            phrase("p2", text: "More", image: nil, media: "Media/clip.mp4"),
            phrase("p3", text: "Hi", image: "emoji:😀", media: "youtube:abc")
        ]

        let items = MediaLibraryCatalog.build(files: files, phrases: phrases)

        XCTAssertEqual(items.map(\.relativePath), [
            "Media/clip.mp4",
            "Images/custom_image_a.jpg",
            "Media/voice.m4a"
        ])
        let video = items[0]
        XCTAssertEqual(video.kind, .video)
        XCTAssertEqual(video.usages.map(\.phraseText), ["Juice", "More"])
        XCTAssertEqual(video.usages.map(\.role), [.playback, .playback])
        XCTAssertEqual(items[1].usages.map(\.role), [.picture])
        XCTAssertTrue(items[2].usages.isEmpty)
    }

    func testAttachPictureKeepsPlaybackAndDropsPoster() {
        let edit = MediaLibraryCatalog.attach(
            path: "Images/custom_image_b.jpg",
            kind: .picture,
            to: MediaLibraryPhraseStyleState(
                imageRef: "Images/video_poster_old.jpg",
                mediaRef: "Media/clip.mp4",
                mediaType: MediaLibraryCatalog.videoMediaType,
                gameType: "blocs"
            )
        )
        XCTAssertEqual(edit.style.imageRef, "Images/custom_image_b.jpg")
        XCTAssertEqual(edit.style.mediaRef, "Media/clip.mp4")
        XCTAssertEqual(edit.style.gameType, "blocs")
        XCTAssertEqual(edit.deletePosterPaths, ["Images/video_poster_old.jpg"])
        XCTAssertFalse(edit.generateVideoPoster)
    }

    func testAttachVideoClearsGameAndKeepsCustomPhoto() {
        let edit = MediaLibraryCatalog.attach(
            path: "Media/clip.mp4",
            kind: .video,
            to: MediaLibraryPhraseStyleState(
                imageRef: "Images/custom_image_a.jpg",
                mediaRef: nil,
                mediaType: nil,
                gameType: "blocs"
            )
        )
        XCTAssertEqual(edit.style.imageRef, "Images/custom_image_a.jpg")
        XCTAssertEqual(edit.style.mediaRef, "Media/clip.mp4")
        XCTAssertEqual(edit.style.mediaType, "video")
        XCTAssertNil(edit.style.gameType)
        XCTAssertFalse(edit.generateVideoPoster)
        XCTAssertTrue(edit.deletePosterPaths.isEmpty)
    }

    func testAttachVideoReplacesGeneratedStill() {
        let edit = MediaLibraryCatalog.attach(
            path: "Media/clip.mp4",
            kind: .video,
            to: MediaLibraryPhraseStyleState(
                imageRef: "Images/video_poster_old.jpg",
                mediaRef: nil,
                mediaType: nil,
                gameType: nil
            )
        )
        XCTAssertNil(edit.style.imageRef)
        XCTAssertEqual(edit.posterPathReplacedByGeneratedStill, "Images/video_poster_old.jpg")
        XCTAssertTrue(edit.generateVideoPoster)
        XCTAssertFalse(edit.deletePosterPaths.contains("Media/clip.mp4"))
    }

    func testAttachAudioClearsPosterAndGameButNotLibraryFile() {
        let edit = MediaLibraryCatalog.attach(
            path: "Media/voice.m4a",
            kind: .audio,
            to: MediaLibraryPhraseStyleState(
                imageRef: "Images/video_poster_old.jpg",
                mediaRef: "Media/clip.mp4",
                mediaType: "video",
                gameType: "blocs"
            )
        )
        XCTAssertNil(edit.style.imageRef)
        XCTAssertEqual(edit.style.mediaRef, "Media/voice.m4a")
        XCTAssertEqual(edit.style.mediaType, "audio")
        XCTAssertNil(edit.style.gameType)
        XCTAssertEqual(edit.deletePosterPaths, ["Images/video_poster_old.jpg"])
    }

    func testUnlinkVideoKeepsCustomPhotoAndDoesNotDeleteLibraryFile() {
        let edit = MediaLibraryCatalog.unlink(
            path: "Media/clip.mp4",
            imageLibraryPath: "Images/custom_image_a.jpg",
            mediaLibraryPath: "Media/clip.mp4",
            from: MediaLibraryPhraseStyleState(
                imageRef: "Images/custom_image_a.jpg",
                mediaRef: "Media/clip.mp4",
                mediaType: "video",
                gameType: nil
            )
        )
        XCTAssertEqual(edit.style.imageRef, "Images/custom_image_a.jpg")
        XCTAssertNil(edit.style.mediaRef)
        XCTAssertNil(edit.style.mediaType)
        XCTAssertTrue(edit.deletePosterPaths.isEmpty)
    }

    func testUnlinkVideoDeletesGeneratedStillOnly() {
        let edit = MediaLibraryCatalog.unlink(
            path: "Media/clip.mp4",
            imageLibraryPath: nil,
            mediaLibraryPath: "Media/clip.mp4",
            from: MediaLibraryPhraseStyleState(
                imageRef: "Images/video_poster_old.jpg",
                mediaRef: "Media/clip.mp4",
                mediaType: "video",
                gameType: nil
            )
        )
        XCTAssertNil(edit.style.imageRef)
        XCTAssertNil(edit.style.mediaRef)
        XCTAssertEqual(edit.deletePosterPaths, ["Images/video_poster_old.jpg"])
    }

    func testUnlinkPictureLeavesPlayback() {
        let edit = MediaLibraryCatalog.unlink(
            path: "Images/custom_image_a.jpg",
            imageLibraryPath: "Images/custom_image_a.jpg",
            mediaLibraryPath: "Media/clip.mp4",
            from: MediaLibraryPhraseStyleState(
                imageRef: "Images/custom_image_a.jpg",
                mediaRef: "Media/clip.mp4",
                mediaType: "video",
                gameType: nil
            )
        )
        XCTAssertNil(edit.style.imageRef)
        XCTAssertEqual(edit.style.mediaRef, "Media/clip.mp4")
        XCTAssertTrue(edit.deletePosterPaths.isEmpty)
    }

    func testLibraryRelativePathIgnoresEmojiYouTubeAndPosters() {
        XCTAssertNil(MediaLibraryStore.libraryRelativePath(for: nil))
        XCTAssertNil(MediaLibraryStore.libraryRelativePath(for: ""))
        XCTAssertNil(MediaLibraryStore.libraryRelativePath(for: "emoji:😀"))
        XCTAssertNil(MediaLibraryStore.libraryRelativePath(for: "youtube:abc"))
        XCTAssertNil(MediaLibraryStore.libraryRelativePath(for: "Images/video_poster_abc.jpg"))
        XCTAssertEqual(
            MediaLibraryStore.libraryRelativePath(for: "Images/custom_image_a.jpg"),
            "Images/custom_image_a.jpg"
        )
        XCTAssertEqual(
            MediaLibraryStore.libraryRelativePath(for: "Media/voice.wav"),
            "Media/voice.wav"
        )
    }

    func testStoredImageResolvesAsLibraryPath() throws {
        let data = Data("library-image".utf8)
        guard let ref = MediaStorage.saveImage(data: data, preferredExtension: "jpg") else {
            XCTFail("saveImage failed")
            return
        }
        defer { MediaStorage.deleteMedia(mediaRef: ref) }

        XCTAssertEqual(MediaLibraryStore.libraryRelativePath(for: ref), ref)
        let stored = MediaStorage.listStoredFiles().map(\.relativePath)
        XCTAssertTrue(stored.contains(ref))

        let url = try XCTUnwrap(MediaStorage.resolveURL(mediaRef: ref))
        XCTAssertEqual(MediaLibraryStore.libraryRelativePath(for: url.path), ref)

        MediaStorage.deleteMedia(mediaRef: ref)
        XCTAssertNil(MediaStorage.resolveURL(mediaRef: ref))
        XCTAssertFalse(MediaStorage.listStoredFiles().map(\.relativePath).contains(ref))
    }

    func testImportAudioLandsInMediaFolder() async throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("library-\(UUID().uuidString).m4a")
        try Data("audio-bytes".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        let ref = try await MediaLibraryStore.importFile(from: source, kind: .audio)
        defer { MediaStorage.deleteMedia(mediaRef: ref) }

        XCTAssertTrue(ref.hasPrefix("Media/"))
        XCTAssertEqual(MediaLibraryCatalog.kind(forRelativePath: ref), .audio)
        XCTAssertNotNil(MediaStorage.resolveURL(mediaRef: ref))
    }

    private func phrase(
        _ id: String,
        text: String,
        image: String?,
        media: String?
    ) -> MediaLibraryPhraseSnapshot {
        MediaLibraryPhraseSnapshot(
            phraseId: id,
            phraseText: text,
            categoryId: "cat",
            categoryName: "Food",
            isPreset: false,
            imageRef: image,
            mediaRef: media
        )
    }
}
