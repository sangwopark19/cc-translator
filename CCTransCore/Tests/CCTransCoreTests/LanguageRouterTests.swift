import Testing
@testable import CCTransCore

@Suite struct LanguageRouterTests {
    let router = LanguageRouter(primary: .korean, secondary: .english)

    @Test func koreanSourceRoutesToSecondary() {
        #expect(router.target(forDetected: .korean) == .english)
    }

    @Test func englishSourceRoutesToPrimary() {
        #expect(router.target(forDetected: .english) == .korean)
    }

    @Test func otherSourceRoutesToPrimary() {
        #expect(router.target(forDetected: Language(code: "ja")) == .korean)
    }
}
