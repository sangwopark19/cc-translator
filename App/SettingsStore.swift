import Foundation
import CCTransCore

enum SettingsKeys {
    static let doubleTapThreshold = "doubleTapThreshold"
    static let primaryTargetCode = "primaryTargetCode"
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

    /// 스마트 양방향의 secondary: primary가 한국어면 영어, 아니면 한국어.
    var secondaryTarget: Language {
        primaryTarget == .korean ? .english : .korean
    }
}
