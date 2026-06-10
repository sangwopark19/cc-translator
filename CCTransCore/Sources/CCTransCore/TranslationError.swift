public enum TranslationError: Error, Equatable {
    case malformedResponse
    case network
    case invalidRequest
    case emptyInput
}
