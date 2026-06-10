import Foundation
import CCTransCore

enum SettingsKeys {
    static let doubleTapThreshold = "doubleTapThreshold"
    static let primaryTargetCode = "primaryTargetCode"
    static let secondaryTargetCode = "secondaryTargetCode"
}

struct SettingsStore {
    private let defaults = UserDefaults.standard

    var threshold: TimeInterval {
        let value = defaults.double(forKey: SettingsKeys.doubleTapThreshold)
        return value == 0 ? 0.4 : value
    }

    var primaryTarget: Language {
        let code = defaults.string(forKey: SettingsKeys.primaryTargetCode) ?? "ko"
        return Language(code: code)
    }

    /// 스마트 양방향의 상대 언어. 설정에서 지정한다(기본 영어).
    /// 원문이 primaryTarget이면 이 언어로, 그 외에는 primaryTarget으로 번역한다.
    var secondaryTarget: Language {
        let code = defaults.string(forKey: SettingsKeys.secondaryTargetCode) ?? "en"
        return Language(code: code)
    }
}
