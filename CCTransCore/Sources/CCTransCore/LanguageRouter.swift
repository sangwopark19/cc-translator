public struct LanguageRouter: Sendable {
    public let primary: Language
    public let secondary: Language

    public init(primary: Language, secondary: Language) {
        self.primary = primary
        self.secondary = secondary
    }

    /// 감지된 원문 언어가 primary면 secondary로, 아니면 primary로 번역한다.
    public func target(forDetected source: Language) -> Language {
        source == primary ? secondary : primary
    }
}
