import SwiftUI
import AppKit
import CCTransCore

struct PopupView: View {
    @Bindable var viewModel: PopupViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch viewModel.state {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("번역 중…").foregroundStyle(.secondary)
                }
            case .result(let result):
                resultView(result)
            case .error(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(width: 360, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .onExitCommand(perform: onClose)
    }

    @ViewBuilder
    private func resultView(_ result: TranslationResult) -> some View {
        HStack(spacing: 6) {
            languageBadge(result.detectedSource.code)
            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
            languageBadge(result.target.code)
            Spacer()
            Button {
                copyToPasteboard(result.translatedText)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("번역문 복사")
        }
        Text(result.translatedText)
            .font(.title3)
            .textSelection(.enabled)
        Divider()
        Text("원문")
            .font(.caption)
            .foregroundStyle(.secondary)
        Text(result.originalText)
            .font(.callout)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
    }

    private func languageBadge(_ code: String) -> some View {
        Text(code.uppercased())
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
