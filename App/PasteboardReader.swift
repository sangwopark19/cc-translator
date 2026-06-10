import AppKit

struct PasteboardReader {
    /// 클립보드의 문자열을 읽어 공백 정리 후 반환한다. 비어있으면 nil.
    func readSelection() -> String? {
        guard let raw = NSPasteboard.general.string(forType: .string) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
