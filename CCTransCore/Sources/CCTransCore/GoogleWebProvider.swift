import Foundation

public struct GoogleWebProvider: TranslationProvider {
    private let httpClient: HTTPClient
    private let endpoint = "https://translate.googleapis.com/translate_a/single"

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func translate(_ text: String, to target: Language) async throws -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslationError.emptyInput }

        var components = URLComponents(string: endpoint)
        components?.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: "auto"),
            URLQueryItem(name: "tl", value: target.code),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: trimmed),
        ]
        guard let url = components?.url else { throw TranslationError.invalidRequest }

        let data = try await httpClient.fetchData(from: url)
        let parsed = try GoogleResponseParser.parse(data)
        return TranslationResult(
            originalText: trimmed,
            translatedText: parsed.translatedText,
            detectedSource: parsed.detectedSource,
            target: target,
            provider: "google"
        )
    }
}
