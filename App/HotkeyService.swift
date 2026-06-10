import AppKit
import CCTransCore

/// 전역 cmd+c keyDown을 감시하고 threshold 내 두 번 입력 시 콜백을 호출한다.
/// Accessibility 권한이 필요하다.
final class HotkeyService {
    private let onDoubleCopy: @MainActor () -> Void
    private var detector: DoubleTapDetector
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let cKeyCode: CGKeyCode = 8  // kVK_ANSI_C

    init(threshold: TimeInterval, onDoubleCopy: @escaping @MainActor () -> Void) {
        self.onDoubleCopy = onDoubleCopy
        self.detector = DoubleTapDetector(threshold: threshold)
    }

    /// 설정 변경 시 더블탭 임계시간을 앱 재시작 없이 갱신한다.
    /// 메인 런루프에서만 호출된다(이벤트 탭 콜백과 동일 스레드).
    func updateThreshold(_ threshold: TimeInterval) {
        detector = DoubleTapDetector(threshold: threshold)
    }

    func start() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon in
                if let refcon {
                    let service = Unmanaged<HotkeyService>.fromOpaque(refcon).takeUnretainedValue()
                    service.handle(event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            NSLog("cctrans: 이벤트 탭 생성 실패 (Accessibility 권한 확인)")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
    }

    deinit {
        tearDown()
    }

    private func tearDown() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        CFMachPortInvalidate(tap)
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(_ event: CGEvent) {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == cKeyCode, event.flags.contains(.maskCommand) else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if detector.register(at: now) {
            // The event-tap callback installs its run-loop source via
            // `CFRunLoopGetCurrent()` inside `start()`, which is only ever called from
            // `applicationDidFinishLaunching` on the main thread. The callback therefore
            // always fires on the main run loop, so the MainActor invariant genuinely
            // holds here and `assumeIsolated` is sound (the handler ultimately drives
            // @MainActor UI code).
            //
            // `onDoubleCopy` is a @MainActor () -> Void, which is implicitly Sendable, so
            // we copy it into a local first; that keeps the non-Sendable `self` out of
            // the actor-isolated region and avoids a spurious "sending self" diagnostic.
            let handler = onDoubleCopy
            MainActor.assumeIsolated {
                handler()
            }
        }
    }
}
