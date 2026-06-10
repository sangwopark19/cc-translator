import Foundation

public struct ParsedTranslation: Equatable, Sendable {
    public let translatedText: String
    public let detectedSource: Language
}

public enum GoogleResponseParser {
    /// translate_a/single 응답: `[[["번역","원문",...], ...], null, "감지언어", ...]`
    public static func parse(_ data: Data) throws -> ParsedTranslation {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let sentences = root.first as? [Any] else {
            throw TranslationError.malformedResponse
        }
        let translated = sentences
            .compactMap { ($0 as? [Any])?.first as? String }
            .joined()
        guard !translated.isEmpty else { throw TranslationError.malformedResponse }
        let sourceCode = (root.count > 2 ? root[2] as? String : nil) ?? "auto"
        return ParsedTranslation(
            translatedText: translated,
            detectedSource: Language(code: sourceCode)
        )
    }
}
