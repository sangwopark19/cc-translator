import Testing
import Foundation
@testable import CCTransCore

@Suite struct GoogleResponseParserTests {
    @Test func parsesSingleSentence() throws {
        let json = #"[[["안녕하세요","Hello",null,null,10]],null,"en"]"#
        let parsed = try GoogleResponseParser.parse(Data(json.utf8))
        #expect(parsed.translatedText == "안녕하세요")
        #expect(parsed.detectedSource == .english)
    }

    @Test func joinsMultipleSentences() throws {
        let json = #"[[["가","A",null,null],["나","B",null,null]],null,"en"]"#
        let parsed = try GoogleResponseParser.parse(Data(json.utf8))
        #expect(parsed.translatedText == "가나")
    }

    @Test func throwsOnMalformed() {
        #expect(throws: TranslationError.malformedResponse) {
            try GoogleResponseParser.parse(Data("not json".utf8))
        }
    }
}
