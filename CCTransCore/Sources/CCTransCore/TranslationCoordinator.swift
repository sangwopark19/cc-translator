public struct TranslationCoordinator: Sendable {
    private let provider: TranslationProvider
    private let router: LanguageRouter
    private let primaryTarget: Language

    public init(provider: TranslationProvider, router: LanguageRouter, primaryTarget: Language) {
        self.provider = provider
        self.router = router
        self.primaryTarget = primaryTarget
    }

    /// primaryTarget으로 1차 번역 후, 감지된 원문 언어에 따라 필요 시 재번역한다.
    public func translate(_ text: String) async throws -> TranslationResult {
        let first = try await provider.translate(text, to: primaryTarget)
        let desired = router.target(forDetected: first.detectedSource)
        if desired == first.target { return first }
        return try await provider.translate(text, to: desired)
    }
}
