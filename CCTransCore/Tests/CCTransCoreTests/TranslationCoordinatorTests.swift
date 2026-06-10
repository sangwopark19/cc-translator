import Testing
@testable import CCTransCore

final class MockProvider: TranslationProvider, @unchecked Sendable {
    private var results: [TranslationResult]
    private(set) var requestedTargets: [Language] = []
    init(results: [TranslationResult]) { self.results = results }
    func translate(_ text: String, to target: Language) async throws -> TranslationResult {
        requestedTargets.append(target)
        return results.removeFirst()
    }
}

@Suite struct TranslationCoordinatorTests {
    let router = LanguageRouter(primary: .korean, secondary: .english)

    @Test func foreignSourceTranslatesOnce() async throws {
        let provider = MockProvider(results: [
            TranslationResult(originalText: "Hello", translatedText: "안녕",
                              detectedSource: .english, target: .korean, provider: "mock")
        ])
        let coordinator = TranslationCoordinator(
            provider: provider, router: router, primaryTarget: .korean
        )

        let result = try await coordinator.translate("Hello")

        #expect(result.translatedText == "안녕")
        #expect(provider.requestedTargets == [.korean])
    }

    @Test func koreanSourceReTranslatesToSecondary() async throws {
        let provider = MockProvider(results: [
            TranslationResult(originalText: "안녕", translatedText: "안녕",
                              detectedSource: .korean, target: .korean, provider: "mock"),
            TranslationResult(originalText: "안녕", translatedText: "Hi",
                              detectedSource: .korean, target: .english, provider: "mock"),
        ])
        let coordinator = TranslationCoordinator(
            provider: provider, router: router, primaryTarget: .korean
        )

        let result = try await coordinator.translate("안녕")

        #expect(result.translatedText == "Hi")
        #expect(result.target == .english)
        #expect(provider.requestedTargets == [.korean, .english])
    }
}
