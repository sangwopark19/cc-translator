public protocol TranslationProvider: Sendable {
    func translate(_ text: String, to target: Language) async throws -> TranslationResult
}
