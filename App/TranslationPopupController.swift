import AppKit
import SwiftUI
import CCTransCore

@MainActor
final class TranslationPopupController {
    private var panel: NSPanel?
    private let viewModel = PopupViewModel()

    func showLoading(near point: NSPoint) {
        viewModel.state = .loading
        present(near: point)
    }

    func showResult(_ result: TranslationResult) {
        viewModel.state = .result(result)
    }

    func showError(_ message: String) {
        viewModel.state = .error(message)
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func present(near point: NSPoint) {
        let size = NSSize(width: 360, height: 240)
        if panel == nil {
            let hosting = NSHostingController(
                rootView: PopupView(viewModel: viewModel, onClose: { [weak self] in self?.close() })
            )
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
        guard let panel else { return }
        panel.setContentSize(size)
        // 커서 아래쪽에 표시 (화면 좌표는 좌하단 원점)
        let origin = NSPoint(x: point.x, y: point.y - size.height - 8)
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }
}
