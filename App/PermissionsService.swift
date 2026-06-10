import ApplicationServices

enum PermissionsService {
    /// Accessibility 신뢰 여부. prompt가 true면 미부여 시 시스템 안내를 띄운다.
    static func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
