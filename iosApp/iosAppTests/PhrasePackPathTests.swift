import XCTest
@testable import iosApp

final class PhrasePackPathTests: XCTestCase {
    func testRejectsParentDirectory() {
        XCTAssertThrowsError(try PhrasePackPath.validatedRelativePath("../evil.txt"))
        XCTAssertThrowsError(try PhrasePackPath.validatedRelativePath("assets/../../evil.txt"))
        XCTAssertThrowsError(try PhrasePackPath.validatedRelativePath("assets/images/../../../etc/passwd"))
    }

    func testRejectsAbsoluteAndEmpty() {
        XCTAssertThrowsError(try PhrasePackPath.validatedRelativePath("/tmp/evil.txt"))
        XCTAssertThrowsError(try PhrasePackPath.validatedRelativePath(""))
        XCTAssertThrowsError(try PhrasePackPath.validatedRelativePath("~/.ssh/id_rsa"))
    }

    func testAllowsPackRelativeAssets() throws {
        XCTAssertEqual(try PhrasePackPath.validatedRelativePath("manifest.json"), "manifest.json")
        XCTAssertEqual(try PhrasePackPath.validatedRelativePath("assets/images/p1.jpg"), "assets/images/p1.jpg")
        XCTAssertEqual(try PhrasePackPath.validatedRelativePath("assets/images/"), "assets/images")
        XCTAssertTrue(PhrasePackPath.isAllowedPackPath("manifest.json"))
        XCTAssertTrue(PhrasePackPath.isAllowedPackPath("assets/images/p1.jpg"))
        XCTAssertTrue(PhrasePackPath.isAllowedPackPath("assets/thumbs/p1.jpg"))
        XCTAssertTrue(PhrasePackPath.isAllowedPackPath("assets/media/p1.mp4"))
        XCTAssertFalse(PhrasePackPath.isAllowedPackPath("evil.txt"))
        XCTAssertFalse(PhrasePackPath.isAllowedPackPath("assets/../manifest.json"))
    }

    func testDestinationStaysInsideExtractRoot() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("s2g-root-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let dest = try PhrasePackPath.destinationURL(extractRoot: root, relativePath: "assets/images/p1.jpg")
        XCTAssertTrue(dest.path.hasPrefix(root.path))
        XCTAssertThrowsError(try PhrasePackPath.destinationURL(extractRoot: root, relativePath: "../outside.txt"))
    }

    func testSanitizedExportFileName() {
        XCTAssertEqual(PhrasePackPath.sanitizedExportFileName("Weather Lesson"), "Weather Lesson.switch2go")
        XCTAssertEqual(PhrasePackPath.sanitizedExportFileName("a/b:c"), "a-b-c.switch2go")
        XCTAssertEqual(PhrasePackPath.sanitizedExportFileName("   "), "PhrasePack.switch2go")
    }
}

final class VideoDurationLimiterTests: XCTestCase {
    func testTwentySecondsAccepted() {
        XCTAssertTrue(VideoDurationLimiter.isWithinLimit(20))
        XCTAssertTrue(VideoDurationLimiter.isWithinLimit(0))
        XCTAssertTrue(VideoDurationLimiter.isWithinLimit(19.9))
    }

    func testTwentyOneSecondsRejected() {
        XCTAssertFalse(VideoDurationLimiter.isWithinLimit(21))
        XCTAssertFalse(VideoDurationLimiter.isWithinLimit(20.2))
        XCTAssertFalse(VideoDurationLimiter.isWithinLimit(.infinity))
        XCTAssertFalse(VideoDurationLimiter.isWithinLimit(.nan))
    }
}
