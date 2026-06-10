import Testing
@testable import CCTransCore

@Suite struct SmokeTests {
    @Test func versionIsSet() {
        #expect(CCTransCore.version == "0.1.0")
    }
}
