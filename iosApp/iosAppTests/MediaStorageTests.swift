import XCTest
@testable import iosApp

final class MediaStorageTests: XCTestCase {
    func testRelativeRefFormat() {
        let ref = MediaStorage.relativeRef(folder: "Images", fileName: "custom_image_test.jpg")
        XCTAssertEqual(ref, "Images/custom_image_test.jpg")
        XCTAssertTrue(MediaStorage.isRelativeFileRef(ref))
    }

    func testYouTubeNotLocal() {
        XCTAssertFalse(MediaStorage.isLocalMediaRef("youtube:abc123"))
        XCTAssertTrue(MediaStorage.isLocalMediaRef("Media/foo.mp4"))
        XCTAssertTrue(MediaStorage.isLocalMediaRef("file:///tmp/foo.mp4"))
    }

    func testSaveAndResolveRelativeImage() throws {
        let data = Data("fake-image".utf8)
        guard let ref = MediaStorage.saveImage(data: data, preferredExtension: "jpg") else {
            XCTFail("saveImage failed")
            return
        }
        XCTAssertTrue(ref.hasPrefix("Images/"))
        let url = MediaStorage.resolveURL(mediaRef: ref)
        XCTAssertNotNil(url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url!.path))
        MediaStorage.deleteMedia(mediaRef: ref)
        XCTAssertNil(MediaStorage.resolveURL(mediaRef: ref))
    }

    func testMimeTypes() {
        XCTAssertEqual(MediaStorage.mimeType(forRelativePath: "Images/a.png"), "image/png")
        XCTAssertEqual(MediaStorage.mimeType(forRelativePath: "Media/a.mp4"), "video/mp4")
    }

    func testResolveMissingRelativeReturnsNil() {
        XCTAssertNil(MediaStorage.resolveURL(mediaRef: "Images/does_not_exist_\(UUID().uuidString).jpg"))
    }

    func testVideoPosterRefDetection() {
        XCTAssertTrue(MediaStorage.isVideoPosterRef("Images/video_poster_abc.jpg"))
        XCTAssertTrue(MediaStorage.isVideoPosterRef("/tmp/video_poster_abc.jpg"))
        XCTAssertFalse(MediaStorage.isVideoPosterRef("Images/custom_image_abc.jpg"))
        XCTAssertFalse(MediaStorage.isVideoPosterRef("emoji:😀"))
        XCTAssertFalse(MediaStorage.isVideoPosterRef("ic_symbol_happy"))
        XCTAssertFalse(MediaStorage.isVideoPosterRef(nil))
        XCTAssertFalse(MediaStorage.isVideoPosterRef(""))
    }

    func testCustomPhotoIsNotAVideoPoster() {
        XCTAssertFalse(MediaStorage.isVideoPosterRef("Images/custom_image_abc.jpg"))
        XCTAssertFalse(MediaStorage.isVideoPosterRef("file:///tmp/still.jpg"))
        XCTAssertFalse(MediaStorage.isVideoPosterRef("emoji:😀"))
        XCTAssertFalse(MediaStorage.isVideoPosterRef("ic_symbol_happy"))
    }

    func testSavePosterImageUsesPosterPrefix() throws {
        let data = Data("fake-poster".utf8)
        guard let ref = MediaStorage.savePosterImage(data: data) else {
            XCTFail("savePosterImage failed")
            return
        }
        XCTAssertTrue(ref.hasPrefix("Images/"))
        XCTAssertTrue(MediaStorage.isVideoPosterRef(ref))
        MediaStorage.deleteMedia(mediaRef: ref)
        XCTAssertNil(MediaStorage.resolveURL(mediaRef: ref))
    }
}
