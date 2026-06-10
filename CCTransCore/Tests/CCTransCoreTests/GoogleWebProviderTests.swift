import Testing
import Foundation
@testable import CCTransCore

final class StubHTTPClient: HTTPClient, @unchecked Sendable {
    let fixture: Data
    private(set) var requestedURLs: [URL] = []
    init(fixture: Data) { self.fixture = fixture }
    func fetchData(from url: URL) async throws -> Data {
        requestedURLs.append(url)
        return fixture
    }
}

@Suite struct GoogleWebProviderTests {
    @Test func buildsRequestAndParsesResult() async throws {
        let json = #"[[["안녕하세요","Hello",null,null]],null,"en"]"#
        let stub = StubHTTPClient(fixture: Data(json.utf8))
        let provider = GoogleWebProvider(httpClient: stub)

        let result = try await provider.translate("Hello", to: .korean)

        #expect(result.translatedText == "안녕하세요")
        #expect(result.originalText == "Hello")
        #expect(result.detectedSource == .english)
        #expect(result.target == .korean)
        #expect(result.provider == "google")

        let url = try #require(stub.requestedURLs.first)
        #expect(url.absoluteString.contains("tl=ko"))
        #expect(url.absoluteString.contains("sl=auto"))
    }
}
