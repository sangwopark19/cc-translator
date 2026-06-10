public struct Language: Equatable, Hashable, Sendable {
    public let code: String
    public init(code: String) { self.code = code }

    public static let korean = Language(code: "ko")
    public static let english = Language(code: "en")
    public static let auto = Language(code: "auto")
}
