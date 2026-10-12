import Foundation
import ObjectiveC
import VocableShared

/// Swift wrapper for PhraseStyle JSON serialization
/// Note: Can't make Kotlin class Codable directly, so we parse manually
struct PhraseStyleData: Codable {
    let backgroundColor: UInt?
    let textColor: UInt?
    let textSizeSp: Float?
    let isBold: Bool
    let borderColor: UInt?
    let borderWidthDp: Float?
    let imageRef: String?
    let mediaRef: String?
    let mediaType: String?
    let gameType: String?
    /// Per-phrase environmental control. Omitted in older JSON (treated as false).
    let sendSwitchOutput: Bool?

    func toPhraseStyle() -> PhraseStyle {
        let style = PhraseStyle(
            backgroundColor: backgroundColor.map { KotlinUInt(value: UInt32($0)) },
            textColor: textColor.map { KotlinUInt(value: UInt32($0)) },
            textSizeSp: textSizeSp.map { KotlinFloat(value: $0) },
            isBold: isBold,
            borderColor: borderColor.map { KotlinUInt(value: UInt32($0)) },
            borderWidthDp: borderWidthDp.map { KotlinFloat(value: $0) },
            imageRef: imageRef,
            mediaRef: mediaRef,
            mediaType: mediaType,
            gameType: gameType
        )
        style.sendSwitchOutput = sendSwitchOutput ?? false
        return style
    }
    
    static func from(_ style: PhraseStyle) -> PhraseStyleData {
        return PhraseStyleData(
            backgroundColor: style.backgroundColor.map { UInt($0.uint32Value) },
            textColor: style.textColor.map { UInt($0.uint32Value) },
            textSizeSp: style.textSizeSp?.floatValue,
            isBold: style.isBold,
            borderColor: style.borderColor.map { UInt($0.uint32Value) },
            borderWidthDp: style.borderWidthDp?.floatValue,
            imageRef: style.imageRef,
            mediaRef: style.mediaRef,
            mediaType: style.mediaType,
            gameType: style.gameType,
            sendSwitchOutput: style.sendSwitchOutput ? true : nil
        )
    }
}

/// Helper to convert PhraseStyle to/from JSON
extension PhraseStyle {
    static let EMOJI_PREFIX = "emoji:"
    
    /// Extract emoji from imageRef if it's an emoji reference
    static func extractEmoji(ref: String?) -> String? {
        guard let ref = ref, !ref.isEmpty else { return nil }
        return ref.hasPrefix(EMOJI_PREFIX) ? String(ref.dropFirst(EMOJI_PREFIX.count)) : nil
    }
    
    /// Encode to JSON string
    func toJSONString() -> String? {
        let data = PhraseStyleData.from(self)
        let encoder = JSONEncoder()
        guard let jsonData = try? encoder.encode(data) else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }
    
    /// Decode from JSON string. SQLDelight style columns are nullable.
    static func fromJSONString(_ json: String?) -> PhraseStyle? {
        guard let json, !json.isEmpty else { return nil }
        guard let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        guard let styleData = try? decoder.decode(PhraseStyleData.self, from: data) else { return nil }
        return styleData.toPhraseStyle()
    }

    /// Blocs game id (mirrors KMP `GAME_TYPE_BLOCS`; use `isBlocsGame()` after rebuilding VocableShared).
    func isBlocsGameType() -> Bool {
        gameType == PhraseGameTypeId.blocs
    }

    func isPieCrazyGameType() -> Bool {
        gameType == PhraseGameTypeId.pieCrazy
    }

    /// Stored beside Kotlin PhraseStyle in JSON (`sendSwitchOutput`) without a KMP schema change.
    var sendSwitchOutput: Bool {
        get { objc_getAssociatedObject(self, &phraseStyleSendSwitchOutputKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &phraseStyleSendSwitchOutputKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

private var phraseStyleSendSwitchOutputKey: UInt8 = 0

/// Game type strings stored on phrase styles (local until shared framework includes new constants).
enum PhraseGameTypeId {
    static let blocs = "blocs"
    static let pieCrazy = "pie_crazy"
}
