import AppKit
import CCTransCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyService: HotkeyService?
    private let pasteboardReader = PasteboardReader()
    private let popupController = TranslationPopupController()
    private let settings = SettingsStore()

    private lazy var coordinator: TranslationCoordinator = {
        let provider = GoogleWebProvider(httpClient: URLSessionHTTPClient())
        let router = LanguageRouter(primary: settings.primaryTarget, secondary: settings.secondaryTarget)
        return TranslationCoordinator(provider: provider, router: router, primaryTarget: settings.primaryTarget)
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !PermissionsService.isAccessibilityTrusted(prompt: true) {
            NSLog("cctrans: Accessibility 권한 필요")
        }
        let service = HotkeyService(threshold: settings.threshold) { [weak self] in
            self?.handleTranslateTrigger()
        }
        service.start()
        hotkeyService = service
    }

    private func handleTranslateTrigger() {
        guard let text = pasteboardReader.readSelection() else { return }
        let location = NSEvent.mouseLocation
        popupController.showLoading(near: location)
        Task {
            do {
                let result = try await coordinator.translate(text)
                popupController.showResult(result)
            } catch {
                popupController.showError("번역에 실패했습니다. 잠시 후 다시 시도하세요.")
            }
        }
    }
}
