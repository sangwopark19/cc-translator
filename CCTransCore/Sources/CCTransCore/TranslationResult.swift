public struct TranslationResult: Equatable, Sendable {
    public let originalText: String
    public let translatedText: String
    public let detectedSource: Language
    public let target: Language
    public let provider: String

    public init(
        originalText: String,
        translatedText: String,
        detectedSource: Language,
        target: Language,
        provider: String
    ) {
        self.originalText = originalText
        self.translatedText = translatedText
        self.detectedSource = detectedSource
        self.target = target
        self.provider = provider
    }
}
