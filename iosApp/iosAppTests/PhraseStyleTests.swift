import XCTest
@testable import iosApp
import VocableShared

/// Unit tests for PhraseStyle
class PhraseStyleTests: XCTestCase {
    
    func testDefaultStyle() {
        let style = PhraseStyle()
        
        XCTAssertNil(style.backgroundColor)
        XCTAssertNil(style.textColor)
        XCTAssertNil(style.textSizeSp)
        XCTAssertFalse(style.isBold)
        XCTAssertNil(style.borderColor)
        XCTAssertNil(style.borderWidthDp)
        XCTAssertNil(style.imageRef)
        XCTAssertNil(style.mediaRef)
        XCTAssertNil(style.mediaType)
    }
    
    func testEffectiveValues() {
        let style = PhraseStyle()
        
        // Should return defaults when not set
        XCTAssertEqual(style.effectiveBackgroundColor(), PhraseStyle.companion.DEFAULT_BACKGROUND_COLOR)
        XCTAssertEqual(style.effectiveTextColor(), PhraseStyle.companion.DEFAULT_TEXT_COLOR)
        XCTAssertEqual(style.effectiveTextSize(), PhraseStyle.companion.DEFAULT_TEXT_SIZE_SP)
        XCTAssertEqual(style.effectiveBorderWidth(), PhraseStyle.companion.DEFAULT_BORDER_WIDTH_DP)
        XCTAssertEqual(style.effectiveBorderColor(), PhraseStyle.companion.DEFAULT_BORDER_COLOR)
    }
    
    func testCustomStyle() {
        let style = PhraseStyle(
            backgroundColor: 0xFFE53935,
            textColor: 0xFFFFFFFF,
            textSizeSp: 24.0,
            isBold: true,
            borderColor: 0xFF000000,
            borderWidthDp: 10.0,
            imageRef: "ic_symbol_happy"
        )
        
        XCTAssertEqual(style.backgroundColor, 0xFFE53935)
        XCTAssertEqual(style.textColor, 0xFFFFFFFF)
        XCTAssertEqual(style.textSizeSp, 24.0)
        XCTAssertTrue(style.isBold)
        XCTAssertEqual(style.borderColor, 0xFF000000)
        XCTAssertEqual(style.borderWidthDp, 10.0)
        XCTAssertEqual(style.imageRef, "ic_symbol_happy")
    }
    
    func testEmojiExtraction() {
        let emojiRef = "emoji:😀"
        let extracted = PhraseStyle.extractEmoji(ref: emojiRef)
        XCTAssertEqual(extracted, "😀")
        
        let nonEmojiRef = "ic_symbol_happy"
        let notExtracted = PhraseStyle.extractEmoji(ref: nonEmojiRef)
        XCTAssertNil(notExtracted)
    }
    
    func testHasImage() {
        let styleWithImage = PhraseStyle(imageRef: "ic_symbol_happy")
        XCTAssertTrue(styleWithImage.hasImage())
        
        let styleNoImage = PhraseStyle()
        XCTAssertFalse(styleNoImage.hasImage())
        
        let styleEmptyImage = PhraseStyle(imageRef: "")
        XCTAssertFalse(styleEmptyImage.hasImage())
    }
    
    func testPresetColorCount() {
        let colors = PhraseStyle.companion.PRESET_COLORS
        XCTAssertEqual(colors.count, 19, "Should have 19 preset colors")
    }
    
    func testTextSizeOptions() {
        let sizes = PhraseStyle.companion.TEXT_SIZE_OPTIONS
        XCTAssertEqual(sizes.count, 7, "Should have 7 text size options")
        XCTAssertTrue(sizes.contains(18.0), "Should include default size 18sp")
    }
    
    func testBorderWidthOptions() {
        let widths = PhraseStyle.companion.BORDER_WIDTH_OPTIONS
        XCTAssertEqual(widths.count, 6, "Should have 6 border width options")
        XCTAssertTrue(widths.contains(0.0), "Should include 'None' option")
    }
}
