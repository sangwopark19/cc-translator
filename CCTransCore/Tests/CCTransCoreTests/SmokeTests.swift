import Testing
@testable import CCTransCore

@Suite struct ModelTests {
    @Test func languageConstants() {
        #expect(Language.korean.code == "ko")
        #expect(Language.english.code == "en")
        #expect(Language.korean != Language.english)
    }

    @Test func translationResultStoresFields() {
        let r = TranslationResult(
            originalText: "Hello",
            translatedText: "안녕하세요",
            detectedSource: .english,
            target: .korean,
            provider: "google"
        )
        #expect(r.originalText == "Hello")
        #expect(r.translatedText == "안녕하세요")
        #expect(r.detectedSource == .english)
        #expect(r.target == .korean)
        #expect(r.provider == "google")
    }
}
