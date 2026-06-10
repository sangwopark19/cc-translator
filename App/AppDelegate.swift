import AppKit
import CCTransCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyService: HotkeyService?
    private let pasteboardReader = PasteboardReader()
    private let popupController = TranslationPopupController()
    private let settings = SettingsStore()
    private var settingsObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !PermissionsService.isAccessibilityTrusted(prompt: true) {
            NSLog("cctrans: Accessibility 권한 필요")
        }
        let service = HotkeyService(threshold: settings.threshold) { [weak self] in
            self?.handleTranslateTrigger()
        }
        service.start()
        hotkeyService = service

        // 설정(임계시간)을 앱 재시작 없이 반영한다. 대상 언어는 번역마다
        // makeCoordinator()가 현재 설정으로 재구성하므로 별도 처리가 필요 없다.
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.hotkeyService?.updateThreshold(self.settings.threshold)
            }
        }
    }

    // AppDelegate는 앱 생존 기간 동안 유지되므로 옵저버는 프로세스 종료 시 정리된다
    // (수동 removeObserver 불필요). settingsObserver는 등록 토큰 보관용이다.

    /// 매 번역마다 현재 설정으로 코디네이터를 구성한다(대상 언어 즉시 반영).
    private func makeCoordinator() -> TranslationCoordinator {
        let provider = GoogleWebProvider(httpClient: URLSessionHTTPClient())
        let router = LanguageRouter(primary: settings.primaryTarget, secondary: settings.secondaryTarget)
        return TranslationCoordinator(provider: provider, router: router, primaryTarget: settings.primaryTarget)
    }

    private func handleTranslateTrigger() {
        guard let text = pasteboardReader.readSelection() else { return }
        let location = NSEvent.mouseLocation
        popupController.showLoading(near: location)
        let coordinator = makeCoordinator()
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
