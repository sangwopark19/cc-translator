import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if !PermissionsService.isAccessibilityTrusted(prompt: true) {
            NSLog("cctrans: Accessibility 권한 필요 — 시스템 설정에서 허용 필요")
        }
    }
}
