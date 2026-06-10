import AppKit
import SwiftUI
import CCTransCore

@MainActor
final class TranslationPopupController {
    private var panel: NSPanel?
    private let viewModel = PopupViewModel()
    /// 패널의 좌상단 고정 지점. 콘텐츠가 길어져도 위쪽이 고정되고 아래로 자란다.
    private var anchorTopLeft: NSPoint = .zero

    func showLoading(near point: NSPoint) {
        viewModel.state = .loading
        present(at: point)
    }

    func showResult(_ result: TranslationResult) {
        viewModel.state = .result(result)
        repinTopLeft()
    }

    func showError(_ message: String) {
        viewModel.state = .error(message)
        repinTopLeft()
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func present(at point: NSPoint) {
        if panel == nil {
            let hosting = NSHostingController(
                rootView: PopupView(viewModel: viewModel, onClose: { [weak self] in self?.close() })
            )
            // 콘텐츠(SwiftUI 뷰)의 적정 크기에 맞춰 패널이 자동 리사이즈된다.
            hosting.sizingOptions = [.preferredContentSize]
            let newPanel = NSPanel(contentViewController: hosting)
            newPanel.styleMask = [.titled, .closable, .fullSizeContentView, .nonactivatingPanel]
            newPanel.titleVisibility = .hidden
            newPanel.titlebarAppearsTransparent = true
            newPanel.isMovableByWindowBackground = true
            newPanel.isFloatingPanel = true
            newPanel.level = .floating
            newPanel.hidesOnDeactivate = false
            panel = newPanel
        }
        // 커서 살짝 아래에 좌상단을 고정 (화면 좌표는 좌하단 원점)
        anchorTopLeft = NSPoint(x: point.x + 8, y: point.y - 8)
        guard let panel else { return }
        panel.setFrameTopLeftPoint(anchorTopLeft)
        panel.orderFrontRegardless()
    }

    /// 콘텐츠가 바뀌어 패널 높이가 변하면(loading → result) 좌상단을 다시 고정한다.
    private func repinTopLeft() {
        guard panel != nil else { return }
        Task { @MainActor [weak self] in
            guard let self, let panel = self.panel else { return }
            panel.setFrameTopLeftPoint(self.anchorTopLeft)
        }
    }
}
