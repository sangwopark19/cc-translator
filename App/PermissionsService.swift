import ApplicationServices

enum PermissionsService {
    /// Accessibility 신뢰 여부. prompt가 true면 미부여 시 시스템 안내를 띄운다.
    static func isAccessibilityTrusted(prompt: Bool) -> Bool {
        // `kAXTrustedCheckOptionPrompt` is imported from C as a mutable global, which
        // Swift 6 flags as non-concurrency-safe. It is in fact an immutable CFString
        // constant whose documented value is "AXTrustedCheckOptionPrompt"; using the
        // literal sidesteps the false positive without any unsafe opt-out.
        let key = "AXTrustedCheckOptionPrompt"
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
