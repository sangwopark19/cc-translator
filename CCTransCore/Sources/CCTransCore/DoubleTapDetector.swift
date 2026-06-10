import Foundation

public struct DoubleTapDetector: Sendable {
    public let threshold: TimeInterval
    private var lastTimestamp: TimeInterval?

    public init(threshold: TimeInterval) {
        self.threshold = threshold
    }

    /// 직전 탭과의 간격이 threshold 이내면 true(트리거)를 반환하고 상태를 리셋한다.
    public mutating func register(at timestamp: TimeInterval) -> Bool {
        if let last = lastTimestamp, timestamp - last <= threshold {
            lastTimestamp = nil
            return true
        }
        lastTimestamp = timestamp
        return false
    }
}
