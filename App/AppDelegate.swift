import AppKit
import CCTransCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyService: HotkeyService?
    private let pasteboardReader = PasteboardReader()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !PermissionsService.isAccessibilityTrusted(prompt: true) {
            NSLog("cctrans: Accessibility 권한 필요")
        }
        let service = HotkeyService(threshold: 0.4) { [weak self] in
            let text = self?.pasteboardReader.readSelection() ?? "(없음)"
            NSLog("cctrans: double-copy 감지 → \(text)")
        }
        service.start()
        hotkeyService = service
    }
}
